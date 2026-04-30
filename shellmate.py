import click
import platform
import subprocess
import os
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.syntax import Syntax
from rich.text import Text
from datetime import datetime
from db import Database
from ia import traduzir_comando

console = Console()
db = Database()

SISTEMA = platform.system()  

def exibir_banner():
    banner = """
   _____ __         ____  __  ___      __     
  / ___// /_  ___  / / / /  |/  /___ _/ /____ 
  \\__ \\/ __ \\/ _ \\/ / / / /|_/ / __ `/ __/ _ \\
 ___/ / / / /  __/ / / / /  / / /_/ / /_/  __/
/____/_/ /_/\\___/_/_/ /_/  /_/\\__,_/\\__/\\___/ 
    """
    console.print(banner, style="bold cyan")
    console.print(f"  Sistema detectado: [bold green]{SISTEMA}[/bold green]")
    console.print(f"  Digite [bold yellow]sair[/bold yellow] para encerrar\n")


def executar_comando(comando):
    """Executa o comando no terminal e retorna o resultado."""
    try:
        if SISTEMA == "Windows":
            result = subprocess.run(
                ["powershell", "-Command", comando],
                capture_output=True, text=True, timeout=30
            )
        else:
            result = subprocess.run(
                comando, shell=True,
                capture_output=True, text=True, timeout=30
            )

        saida = result.stdout.strip() if result.stdout else ""
        erro = result.stderr.strip() if result.stderr else ""

        if result.returncode == 0:
            return True, saida if saida else "Comando executado com sucesso."
        else:
            return False, erro if erro else "Erro ao executar o comando."

    except subprocess.TimeoutExpired:
        return False, "Tempo limite excedido (30s)."
    except Exception as e:
        return False, f"Erro: {str(e)}"


@click.group(invoke_without_command=True)
@click.pass_context
def cli(ctx):
    """ShellMate - Terminal Inteligente com IA"""
    if ctx.invoked_subcommand is None:
        iniciar_modo_interativo()


@cli.command()
@click.argument("pedido", nargs=-1, required=True)
def ask(pedido):
    """Traduz um pedido direto. Ex: shellmate ask mostra meu ip"""
    texto = " ".join(pedido)
    processar_pedido(texto)


@cli.command()
@click.option("--limite", "-l", default=10, help="Quantidade de registros")
def historico(limite):
    """Mostra o histórico de comandos."""
    registros = db.listar_historico(limite)

    if not registros:
        console.print("\n[yellow]Nenhum comando no histórico ainda.[/yellow]\n")
        return

    tabela = Table(title="Histórico de Comandos", show_lines=True)
    tabela.add_column("Data", style="dim", width=18)
    tabela.add_column("Pedido", style="cyan")
    tabela.add_column("Comando", style="green")
    tabela.add_column("Exec?", justify="center", width=6)

    for reg in registros:
        data = reg[6] if reg[6] else "-"
        tabela.add_row(
            str(data)[:16],
            reg[1],
            reg[2],
            "✓" if reg[4] else "✗"
        )

    console.print()
    console.print(tabela)
    console.print()


@cli.command()
@click.argument("termo")
def buscar(termo):
    """Busca no histórico por palavra-chave."""
    registros = db.buscar_historico(termo)

    if not registros:
        console.print(f"\n[yellow]Nenhum resultado para '{termo}'.[/yellow]\n")
        return

    tabela = Table(title=f"Resultados para '{termo}'", show_lines=True)
    tabela.add_column("Pedido", style="cyan")
    tabela.add_column("Comando", style="green")

    for reg in registros:
        tabela.add_row(reg[1], reg[2])

    console.print()
    console.print(tabela)
    console.print()


def processar_pedido(texto):
    """Processa um pedido: busca cache ou chama a IA."""

    # Verifica se já existe no cache
    cache = db.buscar_cache(texto, SISTEMA)
    if cache:
        comando = cache[2]
        console.print(
            Panel(
                f"[bold green]{comando}[/bold green]\n\n[dim](cache - já pedido antes)[/dim]",
                title="Comando",
                border_style="green"
            )
        )
    else:
        # Chama a IA
        with console.status("[cyan]Pensando...[/cyan]"):
            comando = traduzir_comando(texto, SISTEMA)

        if not comando:
            console.print("[red]Erro ao obter resposta da IA.[/red]")
            return

        console.print(
            Panel(
                f"[bold green]{comando}[/bold green]",
                title="Comando Gerado",
                border_style="green"
            )
        )

    # Confirmação
    resposta = console.input("\n[bold yellow]Executar? (s/n): [/bold yellow]").strip().lower()

    if resposta in ("s", "sim", "y", "yes"):
        with console.status("[cyan]Executando...[/cyan]"):
            sucesso, resultado = executar_comando(comando)

        if sucesso:
            console.print(Panel(resultado, title="Resultado", border_style="green"))
        else:
            console.print(Panel(resultado, title="Erro", border_style="red"))

        db.salvar(texto, comando, SISTEMA, True, resultado)
    else:
        console.print("[dim]Comando não executado.[/dim]")
        db.salvar(texto, comando, SISTEMA, False, None)


def iniciar_modo_interativo():
    """Loop interativo do ShellMate."""
    exibir_banner()

    while True:
        try:
            texto = console.input("[bold cyan]→ [/bold cyan]").strip()

            if not texto:
                continue

            if texto.lower() in ("sair", "exit", "quit"):
                console.print("\n[dim]Até mais! 👋[/dim]\n")
                break

            if texto.lower() == "historico":
                ctx = click.Context(historico)
                historico.invoke(ctx, limite=10)
                continue

            processar_pedido(texto)
            console.print()

        except (KeyboardInterrupt, EOFError):
            console.print("\n\n[dim]Até mais! 👋[/dim]\n")
            break


if __name__ == "__main__":
    cli()
