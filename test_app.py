from app import app, greet


def test_greet():
    assert greet("World") == "Hello, World!"


def test_home_route():
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200
    assert b"Hello, Jenkins!" in response.data
