/**
 * Render a JSON resource into an HTML table.
 *
 * Usage:
 * import { renderTable } from '/pages/apps/common/js/json-table.js';
 * renderTable('#myTable', '/memory/file-index.json');
 *
 * @param {string} selector CSS selector for the table element
 * @param {string} url Path to the JSON file
 */
export async function renderTable(selector, url) {
  const table = document.querySelector(selector);
  if (!table) return;
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Failed to fetch ${url}: ${res.status}`);
    const json = await res.json();
    let rows;
    if (Array.isArray(json)) {
      rows = json;
    } else if (Array.isArray(json.files)) {
      rows = json.files;
    } else {
      rows = Object.entries(json).map(([key, value]) => ({ key, value }));
    }
    if (rows.length === 0) {
      table.innerHTML = '<caption>No data to display</caption>';
      return;
    }
    // Determine columns from keys of first row
    const cols = Object.keys(rows[0]);
    const thead = document.createElement('thead');
    const headRow = document.createElement('tr');
    cols.forEach(col => {
      const th = document.createElement('th');
      th.textContent = col;
      headRow.appendChild(th);
    });
    thead.appendChild(headRow);
    const tbody = document.createElement('tbody');
    rows.forEach(row => {
      const tr = document.createElement('tr');
      cols.forEach(col => {
        const td = document.createElement('td');
        const val = row[col];
        td.textContent = typeof val === 'object' ? JSON.stringify(val) : val;
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
    table.innerHTML = '';
    table.appendChild(thead);
    table.appendChild(tbody);
  } catch (err) {
    console.error(err);
    table.innerHTML = `<caption>Error loading data: ${err.message}</caption>`;
  }
}