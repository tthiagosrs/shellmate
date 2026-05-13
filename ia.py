from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate

API_KEY = "AIzaSyASB-lIZ3QXikoh4xAh1IGtRMeUqcTAGkM"

llm = ChatGoogleGenerativeAI(
    model="gemini-flash-latest",
    google_api_key=API_KEY,
    temperature=0
)

template = PromptTemplate(
    input_variables=["so_nome", "pedido"],
    template="""Você é um tradutor de linguagem natural para comandos de terminal.

O usuário está usando: {so_nome}

Regras:
- Retorne APENAS o comando, sem explicação, sem markdown, sem crases
- Se precisar de múltiplos comandos, separe com && (Linux/Mac) ou ; (PowerShell)
- Use comandos nativos do sistema sempre que possível
- Se o pedido não fizer sentido como comando de terminal, responda apenas: ERRO
- Nunca retorne comandos destrutivos como rm -rf / ou format sem que o usuário peça explicitamente

Pedido do usuário: {pedido}

Comando:"""
)

chain = template | llm


def traduzir_comando(pedido: str, sistema_operacional: str) -> str:

    so_map = {
        "Windows": "Windows (PowerShell)",
        "Linux": "Linux (Bash)",
        "Darwin": "macOS (Bash/Zsh)"
    }

    so_nome = so_map.get(sistema_operacional, sistema_operacional)

    try:
        response = chain.invoke({
            "so_nome": so_nome,
            "pedido": pedido
        })

        # Trata caso o content venha como lista ou string
        if isinstance(response.content, list):
            partes = [p.get("text", "") if isinstance(p, dict) else str(p) for p in response.content]
            comando = "".join(partes)
        else:
            comando = response.content

        comando = comando.strip()
        comando = comando.replace("```bash", "").replace("```powershell", "")
        comando = comando.replace("```shell", "").replace("```", "").strip()

        if comando == "ERRO" or not comando:
            return None

        return comando

    except Exception as e:
        print(f"Erro na API: {e}")
        return None