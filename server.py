from fastapi import FastAPI, HTTPException, Query
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import subprocess
import shlex
import os
import asyncio
import traceback
from typing import Any

import ia
from db import Database

app = FastAPI(title="Shellmate Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Banco de dados — None se o Postgres não estiver disponível
_db: Database | None = None

try:
    _db = Database()
    print("[DB] Conectado ao PostgreSQL com sucesso.")
except Exception as e:
    print(f"[DB] Não foi possível conectar ao banco: {e}")
    print("[DB] O servidor vai funcionar sem cache e sem histórico.")


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class TranslateRequest(BaseModel):
    pedido: str
    sistema: str = "Windows"
    modo: str = "tecnico"
    usar_groq: bool = False


class TranslateResponse(BaseModel):
    comando: str | None = None
    explicacao: str | None = None
    erro: str | None = None
    ia_usada: str | None = None
    raw: Any = None
    from_cache: bool = False
    historico_id: int | None = None


class RunRequest(BaseModel):
    command: str
    shell: str | None = None
    timeout: int | None = 30
    historico_id: int | None = None


class RunResponse(BaseModel):
    stdout: str
    stderr: str
    returncode: int


class HistoricoItem(BaseModel):
    id: int
    input_usuario: str
    comando_gerado: str
    sistema_operacional: str
    executado: bool
    resultado: str | None
    data_hora: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _row_to_historico(row: dict) -> HistoricoItem:
    return HistoricoItem(
        id=row['id'],
        input_usuario=row['input_usuario'],
        comando_gerado=row['comando_gerado'],
        sistema_operacional=row['sistema_operacional'],
        executado=row['executado'],
        resultado=row.get('resultado'),
        data_hora=str(row['data_hora']),
    )


def _is_dangerous(command: str) -> bool:
    return ia.verificar_comando_perigoso(command)


def _run_subprocess_sync(cmd_list, timeout: int):
    proc = subprocess.run(
        cmd_list,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        shell=False,
    )
    return proc.stdout.decode(errors='ignore'), proc.stderr.decode(errors='ignore'), proc.returncode


async def _run_subprocess(cmd_list, timeout: int):
    return await asyncio.to_thread(_run_subprocess_sync, cmd_list, timeout)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.post('/translate', response_model=TranslateResponse)
async def translate(req: TranslateRequest):
    # Tenta buscar no cache do banco
    if _db is not None:
        try:
            cached = await asyncio.to_thread(_db.buscar_cache, req.pedido, req.sistema)
            if cached:
                return TranslateResponse(
                    comando=cached['comando_gerado'],
                    ia_usada='cache',
                    from_cache=True,
                    historico_id=cached['id'],
                )
        except Exception as e:
            print(f"[DB] Erro ao buscar cache: {e}")

    # Chama a IA
    result = await asyncio.to_thread(
        ia.traduzir_comando,
        req.pedido,
        req.sistema,
        modo=req.modo,
        usar_groq=req.usar_groq,
    )

    raw_response = result.get('raw')
    safe_raw = jsonable_encoder(raw_response) if raw_response is not None else None

    historico_id: int | None = None

    # Salva no banco se gerou um comando
    if _db is not None and result.get('comando'):
        try:
            historico_id = await asyncio.to_thread(
                _db.salvar,
                req.pedido,
                result['comando'],
                req.sistema,
                False,
                None,
            )
        except Exception as e:
            print(f"[DB] Erro ao salvar: {e}")

    return TranslateResponse(
        comando=result.get('comando'),
        explicacao=result.get('explicacao'),
        erro=result.get('erro'),
        ia_usada=result.get('ia_usada'),
        raw=safe_raw,
        from_cache=False,
        historico_id=historico_id,
    )


@app.post('/run', response_model=RunResponse)
async def run_command(req: RunRequest):
    command = req.command.strip()
    if not command:
        raise HTTPException(status_code=400, detail='empty command')

    if _is_dangerous(command):
        raise HTTPException(status_code=403, detail='command blocked as dangerous')

    if req.shell and req.shell.lower() == 'powershell':
        if os.name == 'nt':
            cmd = ['powershell', '-NoProfile', '-NonInteractive', '-Command', command]
        else:
            cmd = ['pwsh', '-NoProfile', '-NonInteractive', '-Command', command]
    elif req.shell and req.shell.lower() == 'bash':
        cmd = ['bash', '-lc', command]
    else:
        if os.name == 'nt':
            cmd = ['powershell', '-NoProfile', '-NonInteractive', '-Command', command]
        else:
            if any(op in command for op in ['|', '&&', ';', '>']):
                cmd = ['bash', '-lc', command]
            else:
                cmd = shlex.split(command)

    try:
        out, err, rc = await _run_subprocess(cmd, timeout=req.timeout or 30)
    except asyncio.TimeoutError:
        raise HTTPException(status_code=504, detail='command timed out')
    except FileNotFoundError as e:
        raise HTTPException(status_code=400, detail=f'runner not found: {e}')
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f'Unexpected runner error: {e}')

    # Atualiza registro no banco como executado
    if _db is not None and req.historico_id is not None:
        resultado_texto = out.strip() or err.strip() or f'returncode={rc}'
        try:
            await asyncio.to_thread(_db.marcar_executado, req.historico_id, resultado_texto)
        except Exception as e:
            print(f"[DB] Erro ao marcar executado: {e}")

    return RunResponse(stdout=out, stderr=err, returncode=rc)


@app.get('/historico', response_model=list[HistoricoItem])
async def listar_historico(limite: int = Query(default=20, ge=1, le=100)):
    if _db is None:
        raise HTTPException(status_code=503, detail='Banco de dados não disponível.')
    try:
        rows = await asyncio.to_thread(_db.listar_historico, limite)
        return [_row_to_historico(r) for r in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get('/buscar', response_model=list[HistoricoItem])
async def buscar_historico(termo: str = Query(..., min_length=1)):
    if _db is None:
        raise HTTPException(status_code=503, detail='Banco de dados não disponível.')
    try:
        rows = await asyncio.to_thread(_db.buscar_historico, termo)
        return [_row_to_historico(r) for r in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete('/historico/{historico_id}')
async def excluir_item(historico_id: int):
    if _db is None:
        raise HTTPException(status_code=503, detail='Banco não disponível.')
    try:
        await asyncio.to_thread(_db.excluir, historico_id)
        return {'ok': True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete('/historico')
async def limpar_historico():
    if _db is None:
        raise HTTPException(status_code=503, detail='Banco não disponível.')
    try:
        await asyncio.to_thread(_db.limpar_tudo)
        return {'ok': True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get('/health')
def health():
    return {'status': 'ok', 'db': _db is not None}
