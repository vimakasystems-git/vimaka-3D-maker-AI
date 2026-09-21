from __future__ import annotations
import shutil, subprocess, threading, time, uuid
from pathlib import Path
from urllib.request import Request, urlopen
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

ROOT = Path(__file__).resolve().parents[1]
WEB, DATA = ROOT / "web", ROOT / "data"
MODEL = ROOT / "models" / "stable-fast-3d"
DATA.mkdir(exist_ok=True)
jobs, gpu_lock = {}, threading.Lock()
app = FastAPI(title="Vimaka Mesh Studio", version="1.0.0")

def update(job_id, **values): jobs[job_id].update(values)

def run_generation(job_id, source, texture_resolution, remesh):
    job_dir, out_dir = DATA / job_id, DATA / job_id / "output"
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        with gpu_lock:
            update(job_id, status="running", progress=8, message="Carregando Stable Fast 3D")
            cmd = [str(ROOT/".venv/bin/python"), str(MODEL/"run.py"), str(source),
                   "--output-dir", str(out_dir), "--texture-resolution", str(texture_resolution),
                   "--remesh_option", remesh]
            proc = subprocess.Popen(cmd, cwd=MODEL, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True)
            lines = []
            while proc.poll() is None:
                line = proc.stdout.readline() if proc.stdout else ""
                if line:
                    lines.append(line[-500:])
                    update(job_id, progress=min(88, jobs[job_id]["progress"]+3),
                           message="Reconstruindo geometria, UV e materiais")
                time.sleep(.25)
            if proc.returncode: raise RuntimeError("".join(lines[-12:]) or "Falha no modelo 3D")
            glbs = list(out_dir.rglob("*.glb"))
            if not glbs: raise RuntimeError("O modelo terminou sem produzir arquivo GLB")
            final = job_dir / "modelo.glb"
            shutil.copy2(glbs[0], final)
            update(job_id, status="completed", progress=100, message="Modelo GLB pronto",
                   result=f"/api/jobs/{job_id}/download")
    except Exception as exc:
        update(job_id, status="failed", message=str(exc)[-1200:])

def save_remote(url, target):
    req = Request(url, headers={"User-Agent": "VimakaMeshStudio/1.0"})
    with urlopen(req, timeout=30) as response:
        target.write_bytes(response.read(20_000_001))
    if target.stat().st_size > 20_000_000: raise HTTPException(413, "Imagem maior que 20 MB")

@app.get("/api/health")
def health():
    ready = MODEL.exists() and (ROOT/".venv/bin/python").exists()
    return {"ok": True, "model_ready": ready, "engine": "stable-fast-3d"}

@app.post("/api/jobs")
async def create_job(image: UploadFile | None = File(None), image_url: str | None = Form(None),
                     texture_resolution: int = Form(1024), remesh: str = Form("none")):
    if not image and not image_url: raise HTTPException(400, "Envie uma imagem ou URL")
    if texture_resolution not in (512, 1024, 2048): raise HTTPException(400, "Textura inválida")
    if remesh not in ("none", "triangle", "quad"): raise HTTPException(400, "Remesh inválido")
    job_id = uuid.uuid4().hex
    job_dir = DATA / job_id
    job_dir.mkdir(parents=True)
    ext = Path(image.filename or "").suffix.lower() if image else ".jpg"
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}: ext = ".png"
    source = job_dir / f"entrada{ext}"
    if image:
        content = await image.read(20_000_001)
        if len(content) > 20_000_000: raise HTTPException(413, "Imagem maior que 20 MB")
        source.write_bytes(content)
    else: save_remote(image_url or "", source)
    jobs[job_id] = {"id": job_id, "status": "queued", "progress": 2,
                    "message": "Aguardando GPU", "result": None}
    threading.Thread(target=run_generation,
        args=(job_id, source, texture_resolution, remesh), daemon=True).start()
    return jobs[job_id]

@app.get("/api/jobs/{job_id}")
def get_job(job_id):
    if job_id not in jobs: raise HTTPException(404, "Job não encontrado")
    return jobs[job_id]

@app.get("/api/jobs/{job_id}/download")
def download(job_id):
    target = DATA / job_id / "modelo.glb"
    if not target.exists(): raise HTTPException(404, "Modelo ainda não disponível")
    return FileResponse(target, media_type="model/gltf-binary", filename=f"vimaka-{job_id[:8]}.glb")

app.mount("/", StaticFiles(directory=WEB, html=True), name="web")
