
import math
import sqlite3
import subprocess
import tempfile
import wave

from datetime import datetime, date, time, timedelta
from pathlib import Path


# Localiza o banco de dados já utilizado pelo Flutter.
def localizarBanco():
    diretorio = Path.home() / ".local/share"

    bancos = list(diretorio.rglob("cronograma_remedios.db"))

    if len(bancos) != 1:
        print(
            f"Esperado um banco de dados, encontrados: {len(bancos)}"
        )
        for banco in bancos:
            print(banco)
        return None

    return bancos[0]


# Converte um horário HH:MM para datetime.
def criarHorario(data, horario):
    horas, minutos = map(int, horario.split(":"))

    return datetime.combine(
        data,
        time(hour=horas, minute=minutos),
    )


# Produz um som de alarme com três sinais curtos.
def tocarAlarme():
    frequenciaAmostragem = 44100
    frequenciaSom = 880

    with tempfile.TemporaryDirectory() as diretorio:
        arquivo = Path(diretorio) / "alarme.wav"

        with wave.open(str(arquivo), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(frequenciaAmostragem)

            amostras = bytearray()

            for indice in range(int(frequenciaAmostragem * 2.4)):
                instante = indice / frequenciaAmostragem

                # Três sinais sonoros separados por pausas.
                posicao = instante % 0.8
                volume = 0.25 if posicao < 0.5 else 0.0

                valor = int(
                    32767
                    * volume
                    * math.sin(2 * math.pi * frequenciaSom * instante)
                )

                amostras.extend(
                    valor.to_bytes(2, "little", signed=True)
                )

            audio.writeframes(amostras)

        subprocess.run(
            ["paplay", str(arquivo)],
            timeout=10,
            check=True,
        )


# Envia a notificação e, quando necessário, toca o alarme.
def emitirAlerta(titulo, mensagem, tocarSom):
    subprocess.run(
        [
            "notify-send",
            "-u",
            "critical" if tocarSom else "normal",
            "-a",
            "Cronograma de Medicamentos",
            titulo,
            mensagem,
        ],
        timeout=10,
        check=True,
    )

    if tocarSom:
        tocarAlarme()


# Verifica quais alertas devem ser disparados.
def verificarMedicamentos():
    caminhoBanco = localizarBanco()

    if caminhoBanco is None:
        return

    agora = datetime.now()

    with sqlite3.connect(caminhoBanco, timeout=10) as banco:
        banco.execute("""
            CREATE TABLE IF NOT EXISTS alertas_enviados (
                chave TEXT PRIMARY KEY,
                enviado_em TEXT NOT NULL
            )
        """)

        medicamentos = banco.execute("""
            SELECT id, nome, quantidade, horarios,
                   data_inicio, intervalo_dias
            FROM medicamentos
        """).fetchall()

        registros = {
            linha[0]: linha[1]
            for linha in banco.execute(
                "SELECT chave, situacao FROM registros"
            ).fetchall()
        }

        for medicamento in medicamentos:
            identificador, nome, quantidade, horarios, \
                dataInicio, intervaloDias = medicamento

            if intervaloDias < 1:
                continue

            inicio = date.fromisoformat(dataInicio[:10])

            # Inclui amanhã para lembrar doses após a meia-noite.
            for deslocamento in range(2):
                data = agora.date() + timedelta(days=deslocamento)
                diferencaDias = (data - inicio).days

                if diferencaDias < 0:
                    continue

                if diferencaDias % intervaloDias != 0:
                    continue

                for horario in horarios.split(","):
                    horario = horario.strip()
                    horarioDose = criarHorario(data, horario)

                    chaveDose = (
                        f"{identificador}_{data.isoformat()}_{horario}"
                    )

                    # Uma dose registrada não gera novos alertas.
                    if registros.get(chaveDose) in (
                        "tomado",
                        "nao_tomado",
                    ):
                        continue

                    eventos = [
                        (
                            "lembrete",
                            horarioDose - timedelta(minutes=15),
                            "Lembrete de medicamento",
                            f"{nome}: faltam 15 minutos "
                            f"para {horario}.",
                            False,
                        ),
                        (
                            "alarme",
                            horarioDose,
                            "Hora do medicamento",
                            f"{nome} - {quantidade} às {horario}.",
                            True,
                        ),
                    ]

                    for tipo, momento, titulo, mensagem, som in eventos:
                        atraso = (agora - momento).total_seconds()

                        # Aceita uma pequena tolerância de execução.
                        if not 0 <= atraso < 90:
                            continue

                        chaveAlerta = f"{chaveDose}_{tipo}"

                        existente = banco.execute(
                            "SELECT 1 FROM alertas_enviados "
                            "WHERE chave = ?",
                            (chaveAlerta,),
                        ).fetchone()

                        if existente:
                            continue

                        try:
                            emitirAlerta(titulo, mensagem, som)

                            banco.execute(
                                "INSERT INTO alertas_enviados "
                                "(chave, enviado_em) VALUES (?, ?)",
                                (
                                    chaveAlerta,
                                    datetime.now().isoformat(),
                                ),
                            )
                            banco.commit()

                            print(f"Alerta enviado: {chaveAlerta}")

                        except Exception as erro:
                            print(f"Erro ao enviar alerta: {erro}")


if __name__ == "__main__":
    verificarMedicamentos()
