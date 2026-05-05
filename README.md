# ShellMate 

Terminal inteligente que traduz português em comandos de terminal usando IA.

## Pré-requisitos

- Python 3.10+
- PostgreSQL instalado e rodando

## Instalação

### 1. Clone o projeto

```bash
git clone <url-do-repo>
cd shellmate
```

### 2. Instale as dependências

```bash
pip install -r requirements.txt
```

### 3. Crie o banco no PostgreSQL

Abra o terminal do PostgreSQL e rode:

```sql
CREATE DATABASE shellmate;
```

### 4. Configure a conexão

Abra o arquivo `db.py` e altere os dados de conexão:

```python
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "database": "shellmate",
    "user": "postgres",
    "password": "postgres"
}
```

### 5. Configure a API do Gemini

1. Acesse https://aistudio.google.com
2. Crie uma API Key
3. Abra o arquivo `ia.py` e cole sua chave:

```python
API_KEY = "AIzaSyDuNBTeME8rY3nGhErr33aM6-TBA1-m_Jo"
```

## Como usar

### Modo interativo (principal)

```bash
python shellmate.py
```

Depois é só digitar em português:

```
→ mostra os arquivos mais pesados
→ qual meu ip publico
→ lista as portas abertas
→ mata o processo na porta 8080
```

### Comando direto

```bash
python shellmate.py ask mostra meu ip
```

### Ver histórico

```bash
python shellmate.py historico
```

### Buscar no histórico

```bash
python shellmate.py buscar "porta"
```

## Estrutura do projeto

```
shellmate/
├── shellmate.py       # CLI principal
├── db.py              # Conexão com PostgreSQL
├── ia.py              # Integração com Gemini
├── requirements.txt   # Dependências
└── README.md          # Este arquivo
```

## Funciona em

-  Windows (PowerShell)
-  Linux (Bash)
-  macOS (Bash/Zsh)
