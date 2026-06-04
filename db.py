import psycopg2
from psycopg2.extras import RealDictCursor

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
        with self.conn.cursor() as cur:
            cur.execute("""
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

    def salvar(self, input_usuario, comando, so, executado, resultado) -> int:
        with self.conn.cursor() as cur:
            cur.execute("""
                INSERT INTO historico
                    (input_usuario, comando_gerado, sistema_operacional, executado, resultado)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
            """, (input_usuario, comando, so, executado, resultado))
            return cur.fetchone()[0]

    def marcar_executado(self, historico_id: int, resultado: str):
        with self.conn.cursor() as cur:
            cur.execute("""
                UPDATE historico
                SET executado = TRUE, resultado = %s
                WHERE id = %s
            """, (resultado, historico_id))

    def buscar_cache(self, input_usuario, so) -> dict | None:
        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT * FROM historico
                WHERE LOWER(input_usuario) = LOWER(%s)
                  AND sistema_operacional = %s
                ORDER BY data_hora DESC
                LIMIT 1
            """, (input_usuario, so))
            row = cur.fetchone()
            return dict(row) if row else None

    def listar_historico(self, limite=10) -> list[dict]:
        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT * FROM historico
                ORDER BY data_hora DESC
                LIMIT %s
            """, (limite,))
            return [dict(r) for r in cur.fetchall()]

    def buscar_historico(self, termo) -> list[dict]:
        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT * FROM historico
                WHERE LOWER(input_usuario) LIKE LOWER(%s)
                   OR LOWER(comando_gerado) LIKE LOWER(%s)
                ORDER BY data_hora DESC
                LIMIT 20
            """, (f"%{termo}%", f"%{termo}%"))
            return [dict(r) for r in cur.fetchall()]

    def excluir(self, historico_id: int):
        with self.conn.cursor() as cur:
            cur.execute("DELETE FROM historico WHERE id = %s", (historico_id,))

    def limpar_tudo(self):
        with self.conn.cursor() as cur:
            cur.execute("DELETE FROM historico")

    def __del__(self):
        if hasattr(self, 'conn') and self.conn and not self.conn.closed:
            self.conn.close()
