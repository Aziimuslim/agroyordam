async def test_public_catalog(client):
    plants = (await client.get("/api/v1/plants")).json()
    assert len(plants) >= 6
    tomato = next(p for p in plants if p["name"] == "Pomidor")
    assert (await client.get(f"/api/v1/plants/{tomato['id']}")).status_code == 200
    diseases = (await client.get(f"/api/v1/plants/{tomato['id']}/diseases")).json()
    assert any(d["ai_label"] == "Tomato_Late_blight" for d in diseases)
    detail = (await client.get(f"/api/v1/diseases/{diseases[0]['id']}")).json()
    assert detail["medicines"]
    assert (await client.get("/api/v1/diseases", params={"q": "fitoftoroz"})).json()
    meds = (await client.get("/api/v1/medicines")).json()
    assert (await client.get(f"/api/v1/medicines/{meds[0]['id']}")).status_code == 200


async def test_admin_crud_and_rbac(client, user_headers, admin_headers):
    body = {"name": "Qovun", "scientific_name": "Cucumis melo"}
    assert (await client.post("/api/v1/plants", json=body, headers=user_headers)).status_code == 403
    assert (await client.post("/api/v1/plants", json=body)).status_code == 401
    plant = (await client.post("/api/v1/plants", json=body, headers=admin_headers)).json()
    r = await client.put(f"/api/v1/plants/{plant['id']}", json={"care_info": "Issiq"}, headers=admin_headers)
    assert r.json()["care_info"] == "Issiq"

    d = await client.post("/api/v1/diseases", json={"plant_id": plant["id"], "ai_label": "Melon_X", "name": "X", "risk_level": "low"}, headers=admin_headers)
    assert d.status_code == 201
    dup = await client.post("/api/v1/diseases", json={"ai_label": "Melon_X", "name": "Y"}, headers=admin_headers)
    assert dup.status_code == 409
    did = d.json()["id"]
    assert (await client.put(f"/api/v1/diseases/{did}", json={"risk_level": "high"}, headers=admin_headers)).json()["risk_level"] == "high"

    m = (await client.post("/api/v1/medicines", json={"name": "Dori A"}, headers=admin_headers)).json()
    r = await client.put(f"/api/v1/diseases/{did}/medicines", json={"items": [{"medicine_id": m["id"], "recommendation": "10 g"}]}, headers=admin_headers)
    assert r.json()[0]["recommendation"] == "10 g"
    assert (await client.put(f"/api/v1/medicines/{m['id']}", json={"name": "Dori B"}, headers=admin_headers)).json()["name"] == "Dori B"

    assert (await client.delete(f"/api/v1/diseases/{did}", headers=admin_headers)).status_code == 204
    assert (await client.get(f"/api/v1/diseases/{did}")).status_code == 404
    assert (await client.delete(f"/api/v1/medicines/{m['id']}", headers=admin_headers)).status_code == 204
    assert (await client.delete(f"/api/v1/plants/{plant['id']}", headers=admin_headers)).status_code == 204
    assert (await client.get(f"/api/v1/plants/{plant['id']}")).status_code == 404


async def test_crops_crud_logs_and_limit(client, user_headers):
    plants = (await client.get("/api/v1/plants")).json()
    ids = []
    for i in range(3):
        r = await client.post("/api/v1/crops", json={"name": f"Ekin {i}", "plant_id": plants[i]["id"], "area": "12.5"}, headers=user_headers)
        assert r.status_code == 201
        ids.append(r.json()["id"])
    # bepul rejada 3 tadan ortiq emas
    r = await client.post("/api/v1/crops", json={"name": "Ortiqcha"}, headers=user_headers)
    assert r.status_code == 402
    assert len((await client.get("/api/v1/crops", headers=user_headers)).json()) == 3

    r = await client.put(f"/api/v1/crops/{ids[0]}", json={"variety": "Qizil", "status": "archived"}, headers=user_headers)
    assert r.json()["status"] == "archived"
    assert (await client.post("/api/v1/crops", json={"name": "Endi mumkin"}, headers=user_headers)).status_code == 201

    r = await client.post(f"/api/v1/crops/{ids[1]}/logs", json={"content": "Sug'orildi"}, headers=user_headers)
    assert r.status_code == 201
    assert len((await client.get(f"/api/v1/crops/{ids[1]}/logs", headers=user_headers)).json()) == 1
    hist = (await client.get(f"/api/v1/crops/{ids[1]}/health-history", headers=user_headers)).json()
    assert hist[0]["health_score"] == 100
    assert (await client.delete(f"/api/v1/crops/{ids[1]}", headers=user_headers)).status_code == 204
    assert (await client.get(f"/api/v1/crops/{ids[1]}", headers=user_headers)).status_code == 404


async def test_crop_isolation(client, user_headers):
    from tests.conftest import auth, register

    crop = (await client.post("/api/v1/crops", json={"name": "Meniki"}, headers=user_headers)).json()
    other = auth(await register(client, "intruder"))
    assert (await client.get(f"/api/v1/crops/{crop['id']}", headers=other)).status_code == 404
    assert (await client.delete(f"/api/v1/crops/{crop['id']}", headers=other)).status_code == 404
