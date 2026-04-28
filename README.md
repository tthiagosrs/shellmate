# ShellMate

Terminal inteligente que traduz português em comandos de terminal usando IA.

## Pré-requisitos

- Python 3.10 ou superior
- Conta no Google AI Studio (https://aistudio.google.com)

## Instalação

### 1. Clone o repositório


git clone <url-do-repo>
cd shellmate


### 2. Instale as dependências


pip install -r requirements.txt


### 3. Configure a API Key

1. Acesse https://aistudio.google.com/apikey
2. Clique em "Create API Key"
3. Selecione "Create API key in new project"
4. Copie a chave gerada
5. Abra o arquivo ia.py e substitua o valor da variável API_KEY pela sua chave

### 4. Execute o script de validação


python3 ia.py


### 5. Resultado esperado

Se a conexão estiver funcionando, o terminal vai exibir:


Conexão com Gemini OK!
Resposta da IA: Olá! Como posso ajudá-lo?


## Estrutura do projeto


shellmate/ <br>
├── ia.py              # Script de validação da conexão com a API <br>
├── requirements.txt   # Dependências do projeto <br>
└── README.md          # Este arquivo <br>


## Tecnologias

- Python
- Google Gemini API (google-genai)
