import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "database": "shellmate",
    "user": "postgres",
    "password": "postgres"
}


class Database:
    def __init__(self):
        self.conn = psycopg2.connect(**DB_CONFIG)
        self.conn.autocommit = True
        self._criar_tabela()

    def _criar_tabela(self):
        cursor = self.conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS historico (
                id SERIAL PRIMARY KEY,
                input_usuario TEXT NOT NULL,
                comando_gerado TEXT NOT NULL,
                sistema_operacional VARCHAR(20) NOT NULL,
                executado BOOLEAN DEFAULT FALSE,
                resultado TEXT,
                data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cursor.close()

    def salvar(self, input_usuario, comando, so, executado, resultado):
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO historico (input_usuario, comando_gerado, sistema_operacional, executado, resultado)
            VALUES (%s, %s, %s, %s, %s)
        """, (input_usuario, comando, so, executado, resultado))
        cursor.close()

    def buscar_cache(self, input_usuario, so):
        """Busca se o mesmo pedido já foi feito no mesmo SO."""
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT * FROM historico
            WHERE LOWER(input_usuario) = LOWER(%s)
              AND sistema_operacional = %s
            ORDER BY data_hora DESC
            LIMIT 1
        """, (input_usuario, so))
        resultado = cursor.fetchone()
        cursor.close()
        return resultado

    def listar_historico(self, limite=10):
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT * FROM historico
            ORDER BY data_hora DESC
            LIMIT %s
        """, (limite,))
        registros = cursor.fetchall()
        cursor.close()
        return registros

    def buscar_historico(self, termo):
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT * FROM historico
            WHERE LOWER(input_usuario) LIKE LOWER(%s)
               OR LOWER(comando_gerado) LIKE LOWER(%s)
            ORDER BY data_hora DESC
            LIMIT 20
        """, (f"%{termo}%", f"%{termo}%"))
        registros = cursor.fetchall()
        cursor.close()
        return registros

    def __del__(self):
        if hasattr(self, 'conn') and self.conn:
            self.conn.close()
set