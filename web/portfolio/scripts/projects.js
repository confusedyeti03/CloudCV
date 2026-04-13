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
    const gridEl = document.getElementById('projects-grid');
    
    try {
        const response = await fetch('./data/projects.json');
        
        if (!response.ok) {
            throw new Error(`HTTP error: ${response.status}`);
        }
        
        const data = await response.json();
        const projects = data.projects || [];
        
        if (projects.length === 0) {
            gridEl.innerHTML = `<p class="loading">No projects available.</p>`;
            return;
        }
        
        // Generate HTML for each project
        const html = projects.map(project => `
            <article class="project-card" data-id="${escapeHtml(project.id)}">
                <h3>${escapeHtml(project.title)}</h3>
                <p class="description">${escapeHtml(project.description)}</p>
                
                <div class="badges">
                    ${project.categories.map(cat => `<span class="badge">${escapeHtml(cat)}</span>`).join('')}
                </div>
                
                <div class="tech-stack">
                    ${project.technologies.map(tech => `<span>${escapeHtml(tech)}</span>`).join('')}
                </div>
                
                ${project.highlights ? `
                    <ul class="highlights">
                        ${project.highlights.map(h => `<li>${escapeHtml(h)}</li>`).join('')}
                    </ul>
                ` : ''}
                
                <a href="${escapeUrl(project.github)}" target="_blank" class="btn-github">
                    View on GitHub →
                </a>
            </article>
        `).join('');
        
        gridEl.innerHTML = html;
        
    } catch (error) {
        console.error('Error loading projects:', error);
        gridEl.innerHTML = `
            <div class="error">
                <p>Error loading projects. Please refresh the page.</p>
                <p><small>${escapeHtml(error.message)}</small></p>
            </div>
        `;
    }
}

// Load projects on page load
document.addEventListener('DOMContentLoaded', loadProjects);
