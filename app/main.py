from fastapi import FastAPI, Query
import requests
import socket
from datetime import datetime, timezone, timedelta

FRANKFURTER_API_URL = "https://api.frankfurter.app"

app = FastAPI()


def get_host_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "host_ip": get_host_ip(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/convert")
def convert_currency(
    from_currency: str = Query(..., alias="from"),
    to_currency: str = Query(..., alias="to"),
    amount: float = Query(...),
):
    url = f"{FRANKFURTER_API_URL}/latest?amount={amount}&from={from_currency}&to={to_currency}"
    response = requests.get(url)

    if response.status_code != 200:
        return {
            "error": "Failed to fetch exchange rate",
            "status_code": response.status_code,
            "details": response.text,
        }

    data = response.json()
    rates = data.get("rates", {})
    if to_currency not in rates:
        return {"error": f"Currency '{to_currency}' not found in response"}
    rate = rates[to_currency]
    return {
        "converted": rate,
        "rate": rate / amount if amount != 0 else None,
        "timestamp": datetime.now(timezone(timedelta(hours=2))).isoformat(),
    }
