export async function renderTable(el, url, columns){
  try{
    const data = await fetch(url).then(r=>r.json());
    const rows = Array.isArray(data) ? data : (data.files || data.pages || data.items || []);
    const table = document.createElement('table');
    table.style.width='100%'; table.style.borderCollapse='collapse';
    const thead = document.createElement('thead'); const trh=document.createElement('tr');
    for(const c of columns){ const th=document.createElement('th'); th.textContent=c.label; th.style.textAlign='left'; th.style.padding='8px'; trh.appendChild(th); }
    thead.appendChild(trh); table.appendChild(thead);
    const tbody = document.createElement('tbody');
    for(const row of rows.slice(0,200)){
      const tr=document.createElement('tr');
      for(const c of columns){
        const td=document.createElement('td'); td.style.padding='8px';
        const v = c.path.split('.').reduce((a,k)=>a&&a[k], row);
        td.textContent = (v==null?'':String(v));
        tr.appendChild(td);
      }
      tbody.appendChild(tr);
    }
    table.appendChild(tbody); el.innerHTML=''; el.appendChild(table);
  }catch(e){
    el.innerHTML = '<div style="color:#ef4444">Error loading '+url+': '+e.message+'</div>';
  }
}
