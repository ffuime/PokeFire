const viewer = document.createElement("div");
viewer.className = "help_viewer";
viewer.hidden = true;
viewer.innerHTML = `<button class="help_viewer_close" aria-label="閉じる"><svg viewBox="0 0 24 24"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg></button>
    <div class="help_viewer_stage"><img alt=""></div>
    <p class="help_viewer_caption"></p>`;
document.body.appendChild(viewer);

const viewerStage = viewer.querySelector(".help_viewer_stage");
const viewerImage = viewer.querySelector("img");
const viewerCaption = viewer.querySelector(".help_viewer_caption");
let lastFocus = null;

const openViewer = (img) => {
    lastFocus = document.activeElement;
    viewerImage.src = img.currentSrc || img.src;
    viewerCaption.textContent = img.closest("figure")?.querySelector("figcaption")?.textContent ?? "";
    viewer.classList.remove("is-zoomed");
    viewerImage.style.width = "";
    viewer.hidden = false;
    document.documentElement.classList.add("is-viewer-open");
    viewer.offsetWidth;
    viewer.classList.add("is-open");
    viewer.querySelector(".help_viewer_close").focus({ preventScroll: true });
};

const closeViewer = () => {
    viewer.classList.remove("is-open");
    document.documentElement.classList.remove("is-viewer-open");
    setTimeout(() => {
        if (!viewer.classList.contains("is-open")) viewer.hidden = true;
    }, 200);
    lastFocus?.focus?.({ preventScroll: true });
};

document.querySelectorAll(".help_figure img").forEach((img) => {
    img.tabIndex = 0;
    img.addEventListener("click", () => openViewer(img));
    img.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            openViewer(img);
        }
    });
});

viewer.addEventListener("click", (e) => {
    if (e.target === viewerImage) {
        const zoomed = !viewer.classList.contains("is-zoomed");
        const rect = viewerImage.getBoundingClientRect();
        const ratioX = (e.clientX - rect.left) / rect.width;
        const ratioY = (e.clientY - rect.top) / rect.height;
        viewerImage.style.width = zoomed ? `${Math.max(viewerImage.naturalWidth, rect.width * 2)}px` : "";
        viewer.classList.toggle("is-zoomed", zoomed);
        if (zoomed) {
            viewerStage.scrollLeft = ratioX * viewerStage.scrollWidth - viewerStage.clientWidth / 2;
            viewerStage.scrollTop = ratioY * viewerStage.scrollHeight - viewerStage.clientHeight / 2;
        }
        return;
    }
    if (e.target.closest(".help_viewer_close") || e.target === viewer || e.target === viewerStage) closeViewer();
});

document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !viewer.hidden) closeViewer();
});

const news = document.querySelector(".help_news");
const newsOpen = document.querySelector(".help_news_open");
const closeNews = () => {
    news.classList.remove("is-open");
    setTimeout(() => {
        if (!news.classList.contains("is-open")) news.hidden = true;
    }, 200);
    newsOpen.focus({ preventScroll: true });
};
newsOpen?.addEventListener("click", () => {
    news.hidden = false;
    news.offsetWidth;
    news.classList.add("is-open");
    news.querySelector(".help_news_close").focus({ preventScroll: true });
});
news?.addEventListener("click", (e) => {
    if (e.target === news || e.target.closest(".help_news_close")) closeNews();
});
document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && news && !news.hidden) closeNews();
});
