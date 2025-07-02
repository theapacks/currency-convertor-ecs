from fastapi import FastAPI, Query
import requests
from datetime import datetime, timezone, timedelta

app = FastAPI()


@app.get("/health")
async def health_check():
    return {"status": "healthy"}


@app.get("/convert")
def convert_currency(
    from_currency: str = Query(..., alias="from"),
    to_currency: str = Query(..., alias="to"),
    amount: float = Query(...),
):
    url = f"https://api.frankfurter.app/latest?amount={amount}&from={from_currency}&to={to_currency}"
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
