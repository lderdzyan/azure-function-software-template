import json

import azure.functions as func


app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


@app.route(route="hello", methods=["GET"])
def hello(request: func.HttpRequest) -> func.HttpResponse:
    name = request.params.get("name", "Backstage")

    return func.HttpResponse(
        json.dumps(
            {
                "message": f"Hello, {name}!",
                "service": "${{ values.name }}",
                "status": "ok",
            }
        ),
        mimetype="application/json",
        status_code=200,
    )
