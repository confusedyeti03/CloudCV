/* global pdfjsLib */

const DEFAULT_LANG = "ca";
/**
 * Get the API base URL for fetch requests.
 * 
 * In production, cv_page.html is served by FastAPI at /cv/ via nginx proxy,
 * so all API calls use relative paths (empty base).
 * 
 * For custom setups, set data-api-base on document.body.
 */
const getApiBase = () => {
    const rawBase = document.body?.dataset?.apiBase;
    if (rawBase) {
        return rawBase.replace(/\/+$/, "");
    }
    // FastAPI serves both the page and API, so relative paths work
    return "";
};

const API_BASE = getApiBase();

const elements = {
    iframe: document.getElementById("cv-iframe"),
    downloadBtn: document.getElementById("download-btn"),
    spinner: document.getElementById("spinner"),
    mobileCanvas: document.getElementById("mobile-canvas"),
    visitCount: document.getElementById("visit-count")
};

const labels = {
    ca: "Descarregar CV (PDF)",
    es: "Descargar CV (PDF)",
    en: "Download CV (PDF)"
};

const isMobile = () => window.matchMedia("(max-width: 900px)").matches;

const setActiveTab = (lang) => {
    document.querySelectorAll(".lang-tabs button").forEach((button) => {
        const active = button.dataset.lang === lang;
        button.classList.toggle("active", active);
        button.setAttribute("aria-selected", String(active));
    });
};

const toggleSpinner = (show) => {
    elements.spinner.classList.toggle("visible", show);
};

const updateDownloadLabel = (lang) => {
    elements.downloadBtn.textContent = labels[lang] || labels.ca;
};

const updateLinks = (lang) => {
    const base = API_BASE ? `${API_BASE}/` : "";
    elements.iframe.src = `${base}preview/${lang}`;
    elements.downloadBtn.href = `${base}download/${lang}`;
    updateDownloadLabel(lang);
};

const renderPdfToCanvas = async (lang) => {
    if (!pdfjsLib || !elements.mobileCanvas) {
        return;
    }

    pdfjsLib.GlobalWorkerOptions.workerSrc = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js";
    const base = API_BASE ? `${API_BASE}/` : "";
    const loadingTask = pdfjsLib.getDocument(`${base}preview/${lang}`);
    const pdf = await loadingTask.promise;

    const container = elements.mobileCanvas;
    container.innerHTML = "";

    const dpr = window.devicePixelRatio || 1;
    const containerWidth = container.clientWidth || 0;

    for (let pageNum = 1; pageNum <= pdf.numPages; pageNum += 1) {
        const page = await pdf.getPage(pageNum);
        const baseViewport = page.getViewport({ scale: 1 });
        const scale = containerWidth ? containerWidth / baseViewport.width : 1;
        const viewport = page.getViewport({ scale: scale * dpr });

        const canvas = document.createElement("canvas");
        canvas.width = viewport.width;
        canvas.height = viewport.height;
        canvas.style.width = `${viewport.width / dpr}px`;
        canvas.style.height = `${viewport.height / dpr}px`;
        if (pageNum > 1) {
            canvas.style.marginTop = "8px";
        }
        container.appendChild(canvas);

        const context = canvas.getContext("2d");
        await page.render({ canvasContext: context, viewport }).promise;
    }
};

const loadCv = async (lang) => {
    setActiveTab(lang);
    updateLinks(lang);

    toggleSpinner(true);

    if (isMobile()) {
        try {
            await renderPdfToCanvas(lang);
        } catch (error) {
            console.error("PDF render failed", error);
        }
    }

    if (isMobile()) {
        toggleSpinner(false);
    }
};

const initTabs = () => {
    document.querySelectorAll(".lang-tabs button").forEach((button) => {
        button.addEventListener("click", () => {
            loadCv(button.dataset.lang || DEFAULT_LANG);
        });
    });
};

const updateVisits = async () => {
    try {
        const base = API_BASE ? `${API_BASE}/` : "";
        const response = await fetch(`${base}visits`, { method: "POST" });
        if (!response.ok) {
            return;
        }
        const data = await response.json();
        elements.visitCount.textContent = `Visites: ${data.count}`;
    } catch (error) {
        console.error("Visit count failed", error);
    }
};

const init = () => {
    elements.iframe.addEventListener("load", () => {
        if (!isMobile()) {
            toggleSpinner(false);
        }
    });
    initTabs();
    updateVisits();
    loadCv(DEFAULT_LANG);
};

window.addEventListener("load", init);
window.addEventListener("resize", () => loadCv(document.querySelector(".lang-tabs button.active")?.dataset.lang || DEFAULT_LANG));
