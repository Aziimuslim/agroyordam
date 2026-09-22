from tests.conftest import auth, register


async def test_health(client):
    r = await client.get("/health")
    assert r.status_code == 200 and r.json()["database"] is True


async def test_register_login_me(client):
    tokens = await register(client)
    me = (await client.get("/api/v1/users/me", headers=auth(tokens))).json()
    assert me["username"] == "farmer" and me["role"] == "user" and "password_hash" not in me
    r = await client.post("/api/v1/auth/login", json={"login": "farmer@test.uz", "password": "Secret123!"})
    assert r.status_code == 200 and r.json()["access_token"]


async def test_register_duplicate_and_validation(client):
    await register(client)
    r = await client.post("/api/v1/auth/register", json={"full_name": "X Y", "username": "farmer", "email": "o@t.uz", "password": "Secret123!"})
    assert r.status_code == 409
    r = await client.post("/api/v1/auth/register", json={"full_name": "X Y", "username": "nocontact", "password": "Secret123!"})
    assert r.status_code == 422
    r = await client.post("/api/v1/auth/register", json={"full_name": "X Y", "username": "short", "email": "s@t.uz", "password": "123"})
    assert r.status_code == 422


async def test_login_wrong_password_and_rate_limit(client):
    await register(client)
    for _ in range(5):
        r = await client.post("/api/v1/auth/login", json={"login": "farmer", "password": "wrong"})
        assert r.status_code == 401
    r = await client.post("/api/v1/auth/login", json={"login": "farmer", "password": "Secret123!"})
    assert r.status_code == 429


async def test_refresh_rotation_and_logout(client):
    tokens = await register(client)
    r = await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 200
    new = r.json()
    # eski refresh token qayta ishlamaydi
    assert (await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})).status_code == 401
    assert (await client.post("/api/v1/auth/logout", json={"refresh_token": new["refresh_token"]}, headers=auth(new))).status_code == 204
    assert (await client.post("/api/v1/auth/refresh", json={"refresh_token": new["refresh_token"]})).status_code == 401


async def test_protected_requires_token(client):
    assert (await client.get("/api/v1/users/me")).status_code == 401
    assert (await client.get("/api/v1/users/me", headers={"Authorization": "Bearer junk"})).status_code == 401


async def test_forgot_and_reset_password(client):
    await register(client)
    r = await client.post("/api/v1/auth/forgot-password", json={"login": "farmer"})
    token = r.json()["dev_reset_token"]
    r = await client.post("/api/v1/auth/reset-password", json={"token": token, "new_password": "NewSecret1!"})
    assert r.status_code == 200
    # token bir martalik
    assert (await client.post("/api/v1/auth/reset-password", json={"token": token, "new_password": "Other123!"})).status_code == 400
    r = await client.post("/api/v1/auth/login", json={"login": "farmer", "password": "NewSecret1!"})
    assert r.status_code == 200
    assert (await client.post("/api/v1/auth/reset-password", json={"token": "bad", "new_password": "Other123!"})).status_code == 400


async def test_update_profile_and_avatar(client, user_headers):
    from tests.conftest import image_bytes

    r = await client.put("/api/v1/users/me", json={"full_name": "Yangi Ism", "region": "Toshkent"}, headers=user_headers)
    assert r.json()["full_name"] == "Yangi Ism"
    r = await client.post("/api/v1/users/me/avatar", files={"file": ("a.png", image_bytes(), "image/png")}, headers=user_headers)
    assert r.status_code == 200 and r.json()["avatar_url"].startswith("/media/avatars/")
    r = await client.post("/api/v1/users/me/avatar", files={"file": ("a.png", b"notimage", "image/png")}, headers=user_headers)
    assert r.status_code == 415
    r = await client.post("/api/v1/users/me/avatar", files={"file": ("a.gif", b"GIF89a", "image/gif")}, headers=user_headers)
    assert r.status_code == 415


async def test_follow_flow(client, user_headers):
    other = await register(client, "other")
    other_id = (await client.get("/api/v1/users/me", headers=auth(other))).json()["id"]
    assert (await client.post(f"/api/v1/users/{other_id}/follow", headers=user_headers)).status_code == 204
    prof = (await client.get(f"/api/v1/users/{other_id}", headers=user_headers)).json()
    assert prof["followers_count"] == 1 and prof["is_following"] is True
    assert len((await client.get(f"/api/v1/users/{other_id}/followers", headers=user_headers)).json()) == 1
    me_id = (await client.get("/api/v1/users/me", headers=user_headers)).json()["id"]
    assert len((await client.get(f"/api/v1/users/{me_id}/following", headers=user_headers)).json()) == 1
    notes = (await client.get("/api/v1/notifications", headers=auth(other))).json()
    assert notes[0]["type"] == "follow"
    assert (await client.delete(f"/api/v1/users/{other_id}/follow", headers=user_headers)).status_code == 204
    assert (await client.post(f"/api/v1/users/{me_id}/follow", headers=user_headers)).status_code == 400
