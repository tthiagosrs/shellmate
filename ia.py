from google import genai

API_KEY = "AIzaSyDYCeKXgveNZ0FzpC81wX4Rpb4SUmKaRA8"

client = genai.Client(api_key=API_KEY)


def traduzir_comando(pedido: str, sistema_operacional: str) -> str:

    so_map = {
        "Windows": "Windows (PowerShell)",
        "Linux": "Linux (Bash)",
        "Darwin": "macOS (Bash/Zsh)"
    }

    so_nome = so_map.get(sistema_operacional, sistema_operacional)

    prompt = f"""Você é um tradutor de linguagem natural para comandos de terminal.

O usuário está usando: {so_nome}

Regras:
- Retorne APENAS o comando, sem explicação, sem markdown, sem crases
- Se precisar de múltiplos comandos, separe com && (Linux/Mac) ou ; (PowerShell)
- Use comandos nativos do sistema sempre que possível
- Se o pedido não fizer sentido como comando de terminal, responda apenas: ERRO
- Nunca retorne comandos destrutivos como rm -rf / ou format sem que o usuário peça explicitamente

Pedido do usuário: {pedido}

Comando:"""

    try:
        response = client.models.generate_content(
            model="gemini-flash-latest",
            contents=prompt
        )
        comando = response.text.strip()

        comando = comando.replace("```bash", "").replace("```powershell", "")
        comando = comando.replace("```shell", "").replace("```", "").strip()

        if comando == "ERRO" or not comando:
            return None

        return comando

    except Exception as e:
        print(f"Erro na API: {e}")
        return None