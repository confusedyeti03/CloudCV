async function trackVisit() {
    const countElement = document.getElementById('visit-count');
    
    try {
        // Increment visit counter via API
        const response = await fetch('/api/visits', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error: ${response.status}`);
        }
        
        const data = await response.json();
        countElement.textContent = data.count.toLocaleString();
        
    } catch (error) {
        console.error('Error tracking visit:', error);
        countElement.textContent = '???';
    }
}

// Track visit when page loads
document.addEventListener('DOMContentLoaded', () => {
    trackVisit();

    // Anti-scraping logic for emails
    const emails = document.querySelectorAll('.protected-email');
    emails.forEach(el => {
        el.addEventListener('click', (e) => {
            e.preventDefault();
            const p1 = el.getAttribute('data-p1');
            const p2 = el.getAttribute('data-p2');
            if (p1 && p2) {
                window.location.href = `mailto:${p1}@${p2}`;
            }
        });
    });
});
