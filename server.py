from fastapi import FastAPI, HTTPException
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

app = FastAPI(title="Shellmate Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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


class RunRequest(BaseModel):
    command: str
    shell: str | None = None  # "powershell", "bash", or None
    timeout: int | None = 30


class RunResponse(BaseModel):
    stdout: str
    stderr: str
    returncode: int


@app.post('/translate', response_model=TranslateResponse)
async def translate(req: TranslateRequest):
    # Reuse existing translation logic in ia.py in a thread because it uses blocking I/O.
    result = await asyncio.to_thread(
        ia.traduzir_comando,
        req.pedido,
        req.sistema,
        modo=req.modo,
        usar_groq=req.usar_groq,
    )
    raw_response = result.get('raw')
    safe_raw = jsonable_encoder(raw_response) if raw_response is not None else None
    return TranslateResponse(
        comando=result.get('comando'),
        explicacao=result.get('explicacao'),
        erro=result.get('erro'),
        ia_usada=result.get('ia_usada'),
        raw=safe_raw,
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


@app.post('/run', response_model=RunResponse)
async def run_command(req: RunRequest):
    command = req.command.strip()
    if not command:
        raise HTTPException(status_code=400, detail='empty command')

    # Safety: block dangerous commands
    if _is_dangerous(command):
        raise HTTPException(status_code=403, detail='command blocked as dangerous')

    # Determine runner
    if req.shell and req.shell.lower() == 'powershell':
        # Run inside PowerShell on Windows
        if os.name == 'nt':
            cmd = ['powershell', '-NoProfile', '-NonInteractive', '-Command', command]
        else:
            # Use pwsh if available on non-Windows
            cmd = ['pwsh', '-NoProfile', '-NonInteractive', '-Command', command]
    elif req.shell and req.shell.lower() == 'bash':
        cmd = ['bash', '-lc', command]
    else:
        # On Windows, default to PowerShell for command execution.
        if os.name == 'nt':
            cmd = ['powershell', '-NoProfile', '-NonInteractive', '-Command', command]
        else:
            # Try to split command safely; this may not support pipes or shell features
            # so default to launching through a shell when complex operators are present.
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

    return RunResponse(stdout=out, stderr=err, returncode=rc)


@app.get('/health')
def health():
    return {'status': 'ok'}
