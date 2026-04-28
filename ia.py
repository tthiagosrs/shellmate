from google import genai

API_KEY = "AIzaSyDYCeKXgveNZ0FzpC81wX4Rpb4SUmKaRA8"

client = genai.Client(api_key=API_KEY)

response = client.models.generate_content(
    model="gemini-flash-latest",
    contents="Diga olá em português"
)

print("Conexão com Gemini OK!")
print("Resposta da IA:", response.text)