// Security: HTML Escaping to prevent XSS
const escapeHtml = (str) => {
    if (str === null || str === undefined) return '';
    if (typeof str !== 'string') str = String(str);
    const escapeMap = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#x27;',
        '/': '&#x2F;',
        '`': '&#x60;',
        '=': '&#x3D;'
    };
    return str.replace(/[&<>"'`=/]/g, char => escapeMap[char]);
};

// Escape and validate URL (only allow http, https, mailto)
const escapeUrl = (url) => {
    if (!url || typeof url !== 'string') return '';
    const trimmed = url.trim();
    if (!/^(https?:\/\/|mailto:)/i.test(trimmed)) {
        return '';
    }
    return escapeHtml(trimmed);
};

// Load and render projects
async function loadProjects() {
    const projectsGridEl = document.getElementById('projects-grid');
    const challengesGridEl = document.getElementById('challenges-grid');
    
    try {
        const response = await fetch('./data/projects.json');
        
        if (!response.ok) {
            throw new Error(`HTTP error: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Helper function to generate HTML for an array of items
        const generateHtml = (items) => {
            if (!items || items.length === 0) {
                return `<p class="loading">No items available.</p>`;
            }
            return items.map(item => `
                <article class="project-card" data-id="${escapeHtml(item.id)}">
                    <h3>${escapeHtml(item.title)}</h3>
                    <p class="description">${escapeHtml(item.description)}</p>
                    
                    <div class="badges">
                        ${item.categories.map(cat => `<span class="badge">${escapeHtml(cat)}</span>`).join('')}
                    </div>
                    
                    <div class="tech-stack">
                        ${item.technologies.map(tech => `<span>${escapeHtml(tech)}</span>`).join('')}
                    </div>
                    
                    ${item.highlights ? `
                        <ul class="highlights">
                            ${item.highlights.map(h => `<li>${escapeHtml(h)}</li>`).join('')}
                        </ul>
                    ` : ''}
                    
                    <a href="${escapeUrl(item.github)}" target="_blank" class="btn-github">
                        View on GitHub →
                    </a>
                </article>
            `).join('');
        };
        
        // Render both grids
        if (projectsGridEl) projectsGridEl.innerHTML = generateHtml(data.projects);
        if (challengesGridEl) challengesGridEl.innerHTML = generateHtml(data.challenges);
        
    } catch (error) {
        console.error('Error loading projects:', error);
        const errorHtml = `
            <div class="error">
                <p>Error loading content. Please refresh the page.</p>
                <p><small>${escapeHtml(error.message)}</small></p>
            </div>
        `;
        if (projectsGridEl) projectsGridEl.innerHTML = errorHtml;
        if (challengesGridEl) challengesGridEl.innerHTML = errorHtml;
    }
}

// Load projects on page load
document.addEventListener('DOMContentLoaded', loadProjects);
