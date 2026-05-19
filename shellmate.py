import click
import platform
import subprocess
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.prompt import Prompt
from db import Database
from ia import traduzir_comando, MODOS

console = Console()
db = Database()
SISTEMA = platform.system()

# Modo padrão
modo_atual = "tecnico"
usar_groq = False


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
    console.print(f"  Modo atual: [bold magenta]{modo_atual}[/bold magenta]")
    console.print(f"  IA ativa: [bold blue]{'Groq (Llama3)' if usar_groq else 'Gemini'}[/bold blue]")
    console.print()
    console.print("  Comandos especiais:", style="dim")
    console.print("    [yellow]modo[/yellow]        → trocar modo da IA")
    console.print("    [yellow]trocar ia[/yellow]   → alternar entre Gemini e Groq")
    console.print("    [yellow]historico[/yellow]   → ver comandos anteriores")
    console.print("    [yellow]sair[/yellow]        → encerrar")
    console.print()


def executar_comando(comando):
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


def trocar_modo():
    global modo_atual
    console.print("\n[bold]Modos disponíveis:[/bold]")
    console.print("  [cyan]1[/cyan] → Técnico (respostas profissionais)")
    console.print("  [cyan]2[/cyan] → Resumido (curto e direto)")
    console.print("  [cyan]3[/cyan] → Professor (explica o comando)")
    console.print("  [cyan]4[/cyan] → Detalhado (explica cada parte)")
    console.print("  [cyan]5[/cyan] → Suporte Técnico (amigável)")

    opcao = console.input("\n[bold yellow]Escolha (1-5): [/bold yellow]").strip()

    modos_map = {
        "1": "tecnico",
        "2": "resumido",
        "3": "professor",
        "4": "detalhado",
        "5": "suporte"
    }

    if opcao in modos_map:
        modo_atual = modos_map[opcao]
        console.print(f"\n[green]Modo alterado para: {modo_atual}[/green]\n")
    else:
        console.print("\n[red]Opção inválida.[/red]\n")


def trocar_ia():
    global usar_groq
    usar_groq = not usar_groq
    ia_nome = "Groq (Llama3)" if usar_groq else "Gemini"
    console.print(f"\n[green]IA alterada para: {ia_nome}[/green]\n")


def processar_pedido(texto):
    global modo_atual, usar_groq

    # Verifica cache
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
        resposta = console.input("\n[bold yellow]Executar? (s/n): [/bold yellow]").strip().lower()
        if resposta in ("s", "sim"):
            with console.status("[cyan]Executando...[/cyan]"):
                sucesso, resultado = executar_comando(comando)
            if sucesso:
                console.print(Panel(resultado, title="Resultado", border_style="green"))
            else:
                console.print(Panel(resultado, title="Erro", border_style="red"))
        return

    # Chama a IA
    with console.status(f"[cyan]Pensando ({('Groq' if usar_groq else 'Gemini')})...[/cyan]"):
        resultado = traduzir_comando(texto, SISTEMA, modo=modo_atual, usar_groq=usar_groq)

    # Verifica se foi bloqueado
    if resultado["comando"] is None:
        console.print(Panel(
            f"[bold red]{resultado['erro']}[/bold red]",
            title="Bloqueado",
            border_style="red"
        ))
        return

    comando = resultado["comando"]
    ia_usada = resultado["ia_usada"]

    # Mostra o comando
    console.print(Panel(
        f"[bold green]{comando}[/bold green]\n\n[dim]IA: {ia_usada} | Modo: {modo_atual}[/dim]",
        title="Comando Gerado",
        border_style="green"
    ))

    # Mostra explicação se modo professor ou detalhado
    if resultado.get("explicacao"):
        console.print(Panel(
            resultado["explicacao"],
            title="Explicação",
            border_style="cyan"
        ))

    # Confirmação
    resposta = console.input("\n[bold yellow]Executar? (s/n): [/bold yellow]").strip().lower()

    if resposta in ("s", "sim", "y", "yes"):
        with console.status("[cyan]Executando...[/cyan]"):
            sucesso, resultado_exec = executar_comando(comando)

        if sucesso:
            console.print(Panel(resultado_exec, title="Resultado", border_style="green"))
        else:
            console.print(Panel(resultado_exec, title="Erro", border_style="red"))

        db.salvar(texto, comando, SISTEMA, True, resultado_exec)
    else:
        console.print("[dim]Comando não executado.[/dim]")
        db.salvar(texto, comando, SISTEMA, False, None)


@click.group(invoke_without_command=True)
@click.pass_context
def cli(ctx):
    """ShellMate - Terminal Inteligente com IA"""
    if ctx.invoked_subcommand is None:
        iniciar_modo_interativo()


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
        tabela.add_row(
            str(reg[6])[:16],
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


def iniciar_modo_interativo():
    exibir_banner()

    while True:
        try:
            texto = console.input("[bold cyan]→ [/bold cyan]").strip()

            if not texto:
                continue

            if texto.lower() in ("sair", "exit", "quit"):
                console.print("\n[dim]Até mais! 👋[/dim]\n")
                break

            if texto.lower() == "modo":
                trocar_modo()
                continue

            if texto.lower() in ("trocar ia", "trocar"):
                trocar_ia()
                continue

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