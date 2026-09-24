FROM python:3.11-slim
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# PlantVillage'da o'qitilgan model (GitHub Release "model-v1"). Yuklab bo'lmasa — stub bilan ishlaydi (log'da ogohlantirish)
ARG MODEL_BASE=https://github.com/Aziimuslim/agroyordam/releases/download/model-v1
RUN mkdir -p models && python - <<PY || echo "OGOHLANTIRISH: model yuklanmadi, StubClassifier ishlatiladi"
import urllib.request
for f in ("agro-mobilenetv3.onnx", "agro-mobilenetv3.labels.txt"):
    urllib.request.urlretrieve("${MODEL_BASE}/" + f, "models/" + f)
print("model yuklandi")
PY
ENV MODEL_PATH=/srv/models/agro-mobilenetv3.onnx

COPY app ./app
EXPOSE 8001
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
