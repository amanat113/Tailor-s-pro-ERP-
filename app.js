'use strict';

const App = (() => {
  const VERSION = 'PWA-ZERO-1.0.0';
  const SHOP_ID = 'default_shop';
  const LS = {
    firebaseConfig: 'tailors.firebaseConfig.v1', session: 'tailors.session.v1',
    orders: 'tailors.orders.v1', staff: 'tailors.staff.v1', staffLedger: 'tailors.staffLedger.v1',
    settings: 'tailors.settings.v1', deliveries: 'tailors.deliveries.v1'
  };
  const DEFAULT_SETTINGS = {
    shopName: "Tailor's ERP", address: '', phone: '', slipText: 'Thank you for your order.',
    measurements: ['Length','Chest','Waist','Shoulder','Sleeve']
  };
  const state = {
    view: 'dashboard', user: null, role: 'Owner', drawer: false, loading: false,
    firebaseReady: false, auth: null, db: null, confirmationResult: null,
    orders: [], staff: [], staffLedger: [], deliveries: [], settings: DEFAULT_SETTINGS,
    search: '', activeOrderId: null
  };

  const $ = (id) => document.getElementById(id);
  const app = () => $('app');
  const esc = (v) => String(v ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
  const uid = () => `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 9)}`;
  const nowISO = () => new Date().toISOString();
  const money = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`;
  const today = () => new Date().toISOString().slice(0, 10);
  const read = (key, fallback) => { try { const raw = localStorage.getItem(key); return raw ? JSON.parse(raw) : fallback; } catch { return fallback; } };
  const write = (key, value) => localStorage.setItem(key, JSON.stringify(value));
  const normalizePhone = (phone) => {
    const digits = String(phone || '').replace(/\D/g, '');
    if (digits.length === 10) return `+91${digits}`;
    if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
    if (String(phone).startsWith('+')) return String(phone).trim();
    return `+${digits}`;
  };
  const isValidPhone = (phone) => /^\+91\d{10}$/.test(normalizePhone(phone));
  const byDateDesc = (a,b) => String(b.updatedAt || b.createdAt).localeCompare(String(a.updatedAt || a.createdAt));
  const toast = (msg) => { const t = $('toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toast.t); toast.t = setTimeout(()=>t.classList.remove('show'), 2600); };
  const setView = (view) => { state.view = view; state.drawer = false; render(); };

  function loadLocal() {
    state.orders = read(LS.orders, []);
    state.staff = read(LS.staff, []);
    state.staffLedger = read(LS.staffLedger, []);
    state.deliveries = read(LS.deliveries, []);
    state.settings = { ...DEFAULT_SETTINGS, ...read(LS.settings, DEFAULT_SETTINGS) };
    state.user = read(LS.session, null);
  }
  function persistAll() {
    write(LS.orders, state.orders); write(LS.staff, state.staff); write(LS.staffLedger, state.staffLedger);
    write(LS.deliveries, state.deliveries); write(LS.settings, state.settings);
  }

  async function initFirebase() {
    const cfg = read(LS.firebaseConfig, null);
    if (!cfg || !cfg.apiKey || !window.firebase) return false;
    try {
      if (!firebase.apps.length) firebase.initializeApp(cfg);
      state.auth = firebase.auth(); state.db = firebase.firestore();
      state.db.enablePersistence({ synchronizeTabs: true }).catch(() => null);
      state.firebaseReady = true;
      state.auth.onAuthStateChanged(async (user) => {
        if (user) {
          state.user = { uid: user.uid, phone: user.phoneNumber, role: state.role, loginAt: nowISO() };
          write(LS.session, state.user);
          await syncDown(); render();
        }
      });
      return true;
    } catch (err) {
      console.error(err); toast(`Firebase error: ${err.message || err}`); return false;
    }
  }

  async function syncDown() {
    if (!state.firebaseReady || !state.user) return;
    try {
      const base = state.db.collection('shops').doc(SHOP_ID);
      const [orders, staff, ledger, deliveries, settingsDoc] = await Promise.all([
        base.collection('orders').get(), base.collection('staff').get(), base.collection('staffLedger').get(),
        base.collection('deliveries').get(), base.collection('settings').doc('main').get()
      ]);
      state.orders = orders.docs.map(d => ({ id: d.id, ...d.data() })).sort(byDateDesc);
      state.staff = staff.docs.map(d => ({ id: d.id, ...d.data() })).sort(byDateDesc);
      state.staffLedger = ledger.docs.map(d => ({ id: d.id, ...d.data() })).sort(byDateDesc);
      state.deliveries = deliveries.docs.map(d => ({ id: d.id, ...d.data() })).sort(byDateDesc);
      if (settingsDoc.exists) state.settings = { ...DEFAULT_SETTINGS, ...settingsDoc.data() };
      persistAll();
    } catch (err) { console.warn('syncDown failed', err); }
  }
  async function upsert(collection, item) {
    persistAll();
    if (!state.firebaseReady || !state.user) return;
    const base = state.db.collection('shops').doc(SHOP_ID);
    await base.collection(collection).doc(item.id).set(item, { merge: true });
  }
  async function saveSettings() {
    write(LS.settings, state.settings);
    if (state.firebaseReady && state.user) await state.db.collection('shops').doc(SHOP_ID).collection('settings').doc('main').set(state.settings, { merge: true });
  }

  function authScreen() {
    const hasConfig = !!read(LS.firebaseConfig, null);
    return `<main class="auth-page"><section class="auth-card">
      <div class="brand"><div class="logo">TE</div><div><h1>Tailor's ERP</h1><p>Professional tailoring management</p></div></div>
      ${!hasConfig ? `<div class="error">Firebase Web config is required for real OTP. No demo OTP.</div>` : ''}
      <div class="stack">
        <label><span class="label">Mobile Number</span><input id="loginPhone" inputmode="tel" placeholder="10 digit mobile" /></label>
        <label><span class="label">Role</span><select id="loginRole"><option value="">Select Role</option><option>Owner</option><option>Manager</option><option>Staff</option></select></label>
        <button class="btn" id="sendOtpBtn">Send Real OTP</button>
        <button class="btn secondary" id="setupFirebaseBtn">Firebase Setup</button>
        <p class="hint">This build has no fake/demo login. Add Firebase Web config, enable Phone Auth, and add your GitHub Pages domain in Firebase Authorized Domains.</p>
      </div></section></main>`;
  }
  function otpModal(phone) {
    showModal(`<div class="modal-head"><h3>Verify OTP</h3><button class="icon-btn" data-close>×</button></div>
      <div class="form-grid"><div class="info">OTP sent to ${esc(phone)}</div><input id="otpCode" inputmode="numeric" placeholder="Enter OTP" />
      <input id="pinCode" inputmode="numeric" placeholder="Create / enter 4-8 digit PIN" />
      <button class="btn" id="verifyOtpBtn">Verify & Login</button></div>`);
    $('verifyOtpBtn').onclick = verifyOtp;
  }
  function firebaseSetupModal() {
    const current = JSON.stringify(read(LS.firebaseConfig, {}), null, 2);
    showModal(`<div class="modal-head"><h3>Firebase Web Config</h3><button class="icon-btn" data-close>×</button></div>
    <div class="form-grid"><p class="hint">Firebase Console → Project settings → Your apps → Web app → SDK setup config. Paste the JSON object here.</p>
    <textarea id="firebaseJson" spellcheck="false">${esc(current === '{}' ? '' : current)}</textarea>
    <button class="btn" id="saveFirebaseCfg">Save Firebase Config</button></div>`);
    $('saveFirebaseCfg').onclick = async () => {
      try { const cfg = JSON.parse($('firebaseJson').value); write(LS.firebaseConfig, cfg); closeModal(); await initFirebase(); toast('Firebase config saved.'); render(); }
      catch { toast('Invalid JSON config.'); }
    };
  }
  async function sendOtp() {
    const phone = normalizePhone($('loginPhone').value); const role = $('loginRole').value;
    if (!isValidPhone(phone)) return toast('Enter valid Indian mobile number.');
    if (!role) return toast('Select role first.');
    if (!state.firebaseReady) { await initFirebase(); }
    if (!state.firebaseReady || !state.auth) return firebaseSetupModal();
    state.role = role;
    try {
      window.recaptchaVerifier = window.recaptchaVerifier || new firebase.auth.RecaptchaVerifier('recaptcha-container', { size: 'invisible' });
      state.confirmationResult = await state.auth.signInWithPhoneNumber(phone, window.recaptchaVerifier);
      otpModal(phone);
    } catch (err) { console.error(err); toast(err.message || 'OTP failed. Check Firebase Phone Auth and authorized domain.'); }
  }
  async function verifyOtp() {
    const otp = $('otpCode').value.trim(); const pin = $('pinCode').value.trim();
    if (!/^\d{4,8}$/.test(pin)) return toast('PIN must be 4-8 digits.');
    if (!state.confirmationResult) return toast('Send OTP first.');
    try {
      const res = await state.confirmationResult.confirm(otp);
      state.user = { uid: res.user.uid, phone: res.user.phoneNumber, role: state.role, pin, loginAt: nowISO() };
      write(LS.session, state.user); closeModal(); await syncDown(); toast('Login successful.'); render();
    } catch (err) { toast(err.message || 'Invalid OTP.'); }
  }
  function logout() { localStorage.removeItem(LS.session); if (state.auth) state.auth.signOut().catch(()=>null); state.user = null; render(); }

  function layout(content) {
    return `<div class="layout safe"><header class="topbar"><button class="icon-btn" id="drawerBtn">☰</button><h2>${viewTitle()}</h2><button class="icon-btn" id="syncBtn">↻</button></header><main class="main">${content}</main>${dock()}${drawer()}</div>`;
  }
  function viewTitle() { return ({dashboard:"Tailor's ERP",orders:'New Order',processing:'Processing',delivery:'Delivery',staff:'Staff Ledger',analytics:'Analytics',settings:'Settings'})[state.view] || "Tailor's ERP"; }
  function dock() { const tabs=[['dashboard','⌂','Home'],['processing','▥','Progress'],['orders','+','New'],['delivery','🚚','Delivery'],['staff','👥','Staff']]; return `<nav class="dock">${tabs.map(t=>`<button data-nav="${t[0]}" class="${state.view===t[0]?'active':''} ${t[0]==='orders'?'plus':''}"><span>${t[1]}</span><small>${t[2]}</small></button>`).join('')}</nav>`; }
  function drawer(){ const items=[['dashboard','Home'],['orders','New Order'],['processing','Processing'],['delivery','Delivery'],['staff','Staff Ledger'],['analytics','Analytics'],['settings','Settings']]; return `<aside class="drawer ${state.drawer?'open':''}"><div class="drawer-back" data-close-drawer></div><div class="drawer-panel"><div class="brand"><div class="logo">TE</div><div><h1>${esc(state.settings.shopName)}</h1><p>${esc(state.user?.role || '')} · ${esc(state.user?.phone || '')}</p></div></div>${items.map(i=>`<button data-nav="${i[0]}" class="${state.view===i[0]?'active':''}">${i[1]}</button>`).join('')}<button id="logoutBtn" class="btn danger">Logout</button><p class="hint">Version ${VERSION}</p></div></aside>`; }

  function dashboard() {
    const active = state.orders.filter(o=>o.status !== 'Delivered');
    const totalClothes = active.reduce((s,o)=>s + Number(o.qty||0),0);
    const deliveredQty = state.deliveries.reduce((s,d)=>s+Number(d.qty||0),0);
    const pending = active.reduce((s,o)=>s + remainingQty(o),0);
    const orders = filteredOrders().slice(0,8);
    return layout(`<div class="grid">
      ${metric('📋', state.orders.length, 'Total Orders')}${metric('🧵', active.length, 'Active Orders')}${metric('👕', totalClothes, 'Total Clothes')}${metric('✂️', pending, 'Pending Clothes')}
    </div><div class="search"><input id="quickSearch" value="${esc(state.search)}" placeholder="Search slip or mobile" /></div>
    <div class="section-head"><h3>Recent Orders</h3><button class="link" data-nav="orders">New Order</button></div>
    ${orders.length ? orders.map(orderCard).join('') : `<div class="empty">No orders yet. Tap + New to create first order.</div>`}`);
  }
  function metric(icon,value,label){return `<div class="metric"><i>${icon}</i><br><b>${esc(value)}</b><span>${label}</span></div>`;}
  function filteredOrders(){ const q=state.search.trim().toLowerCase(); return [...state.orders].sort(byDateDesc).filter(o=>!q || String(o.slip).toLowerCase().includes(q) || String(o.mobile).toLowerCase().includes(q)); }
  function orderCard(o){ const due=Number(o.total||0)-Number(o.advance||0)-Number(o.paidOnDelivery||0); return `<article class="card order-card"><div class="order-top"><div class="doc-icon">🧾</div><div><div class="order-title">#${esc(o.slip)} · ${esc(o.name)}</div><div class="small">☎ ${esc(o.mobile)} · ${remainingQty(o)}/${o.qty} remaining · Due ${money(Math.max(due,0))}</div><span class="chip ${String(o.status).toLowerCase()}">${esc(o.status||'Pending')}</span></div></div><div class="actions"><button class="icon-btn" data-call="${esc(o.mobile)}">📞</button><button class="icon-btn" data-edit="${o.id}">✎</button><button class="icon-btn" data-slip="${o.id}">PDF</button></div></article>`; }
  function remainingQty(o){ return Math.max(0, Number(o.qty||0)-Number(o.deliveredQty||0)); }

  function orderForm() {
    const m = state.settings.measurements || [];
    return layout(`<section class="card"><h3>Create New Order</h3><div class="form-grid two">
      <label><span class="label">Manual Slip Number</span><input id="slip" placeholder="SLP-001" /></label>
      <label><span class="label">Customer Name</span><input id="custName" placeholder="Customer name" /></label>
      <label><span class="label">Mobile</span><input id="mobile" inputmode="tel" placeholder="10 digit mobile" /></label>
      <label><span class="label">Cloth Qty</span><input id="qty" type="number" min="1" value="1" /></label>
      <label><span class="label">Total Bill</span><input id="total" type="number" min="0" value="0" /></label>
      <label><span class="label">Advance</span><input id="advance" type="number" min="0" value="0" /></label>
      <label><span class="label">Design URL</span><input id="design" placeholder="Image/design link" /></label>
      <div class="muted-box"><b>Due:</b> <span id="duePreview">₹0</span></div>
      ${m.map(x=>`<label><span class="label">${esc(x)}</span><input data-measure="${esc(x)}" placeholder="${esc(x)}" /></label>`).join('')}
      <label style="grid-column:1/-1"><span class="label">Notes</span><textarea id="notes" placeholder="Special instructions"></textarea></label>
      <button class="btn gold" id="saveOrderBtn">Save Order + WhatsApp + PDF</button>
    </div></section>`);
  }
  async function saveOrder() {
    const slip=$('slip').value.trim(); const name=$('custName').value.trim(); const mobile=normalizePhone($('mobile').value);
    const qty=Math.max(1, Number($('qty').value||1)); const total=Math.max(0, Number($('total').value||0)); const advance=Math.max(0, Number($('advance').value||0));
    if (!slip || !name || !isValidPhone(mobile)) return toast('Slip, name and valid mobile required.');
    if (state.orders.some(o=>String(o.slip).toLowerCase()===slip.toLowerCase())) return toast('Duplicate slip number not allowed.');
    const measurements={}; document.querySelectorAll('[data-measure]').forEach(i=>measurements[i.dataset.measure]=i.value.trim());
    const order={id:uid(),slip,name,mobile,qty,total,advance,design:$('design').value.trim(),notes:$('notes').value.trim(),measurements,status:'Pending',deliveredQty:0,paidOnDelivery:0,createdAt:nowISO(),updatedAt:nowISO()};
    state.orders.unshift(order); await upsert('orders',order); openWhatsapp(mobile, `Hello ${name}, your order (Slip: ${slip}) has been placed. Total: ${total}, Advance: ${advance}, Due: ${total-advance}. Thank you!`); printSlip(order); setView('dashboard');
  }

  function processing() { const list=filteredOrders().filter(o=>o.status!=='Delivered'); return layout(`<div class="search"><input id="quickSearch" value="${esc(state.search)}" placeholder="Search slip number" /></div>${list.length?list.map(o=>`<article class="card"><div class="section-head"><div><b>#${esc(o.slip)}</b><div class="small">${esc(o.name)} · ${remainingQty(o)} remaining</div></div><span class="chip ${String(o.status).toLowerCase()}">${esc(o.status)}</span></div><div class="split"><button class="btn secondary" data-status="${o.id}:Cutting">Cutting Complete</button><button class="btn gold" data-status="${o.id}:Ready">Ready</button></div></article>`).join(''):`<div class="empty">No active orders.</div>`}`); }
  async function updateStatus(id,status){ const o=state.orders.find(x=>x.id===id); if(!o) return; o.status=status; o.updatedAt=nowISO(); await upsert('orders',o); if(status==='Cutting') openWhatsapp(o.mobile,`Hello ${o.name}, cutting for your order (Slip: ${o.slip}) is complete and stitching has begun.`); if(status==='Ready') openWhatsapp(o.mobile,`Good news ${o.name}! Your clothes (Slip: ${o.slip}) are ready for delivery.`); render(); }

  function delivery(){ const list=filteredOrders().filter(o=>o.status==='Ready'||remainingQty(o)>0); return layout(`<div class="search"><input id="quickSearch" value="${esc(state.search)}" placeholder="Search slip number" /></div>${list.length?list.map(o=>`<article class="card"><b>#${esc(o.slip)} · ${esc(o.name)}</b><div class="small">Remaining: ${remainingQty(o)} · Due: ${money(Math.max(Number(o.total)-Number(o.advance)-Number(o.paidOnDelivery||0),0))}</div><div class="row"><input id="delQty-${o.id}" type="number" min="1" max="${remainingQty(o)}" value="1" /><input id="delPay-${o.id}" type="number" min="0" value="0" /></div><button class="btn gold" data-deliver="${o.id}">Confirm Delivery</button></article>`).join(''):`<div class="empty">No orders ready/active.</div>`}`); }
  async function confirmDelivery(id){ const o=state.orders.find(x=>x.id===id); if(!o)return; const qty=Math.max(1,Math.min(remainingQty(o),Number($(`delQty-${id}`).value||1))); const paid=Math.max(0,Number($(`delPay-${id}`).value||0)); o.deliveredQty=Number(o.deliveredQty||0)+qty; o.paidOnDelivery=Number(o.paidOnDelivery||0)+paid; if(remainingQty(o)===0)o.status='Delivered'; o.updatedAt=nowISO(); const d={id:uid(),orderId:o.id,slip:o.slip,name:o.name,mobile:o.mobile,qty,paid,createdAt:nowISO()}; state.deliveries.unshift(d); await upsert('orders',o); await upsert('deliveries',d); openWhatsapp(o.mobile,`Thank you ${o.name}! Your order (Slip: ${o.slip}) has been successfully delivered.`); render(); }

  function staffView(){ return layout(`<section class="card"><h3>Add Staff</h3><div class="row"><input id="staffName" placeholder="Staff name" /><input id="staffSpec" placeholder="Specialization" /></div><button class="btn" id="addStaffBtn">Add Staff</button></section><section class="card"><h3>Daily Work Entry</h3><div class="form-grid two"><select id="staffSelect"><option value="">Select staff</option>${state.staff.map(s=>`<option value="${s.id}">${esc(s.name)}</option>`).join('')}</select><input id="workType" placeholder="Stitch type" /><input id="rate" type="number" placeholder="Rate" /><select id="workQty">${Array.from({length:10},(_,i)=>`<option>${i+1}</option>`).join('')}</select><input id="paidToday" type="number" placeholder="Paid today" /><button class="btn gold" id="saveWorkBtn">Save Work</button></div></section><section class="card"><h3>Staff Summary</h3>${staffSummary()}</section>`); }
  function staffSummary(){ if(!state.staff.length)return `<div class="empty">No staff added.</div>`; return `<table class="table"><thead><tr><th>Staff</th><th>Work</th><th>Paid</th><th>Balance</th></tr></thead><tbody>${state.staff.map(s=>{const rows=state.staffLedger.filter(l=>l.staffId===s.id);const work=rows.reduce((a,b)=>a+Number(b.earning||0),0);const paid=rows.reduce((a,b)=>a+Number(b.paid||0),0);return `<tr><td>${esc(s.name)}</td><td>${money(work)}</td><td>${money(paid)}</td><td>${money(work-paid)}</td></tr>`}).join('')}</tbody></table>`;}
  async function addStaff(){ const name=$('staffName').value.trim(); if(!name)return toast('Staff name required'); const s={id:uid(),name,specialization:$('staffSpec').value.trim(),createdAt:nowISO(),updatedAt:nowISO()}; state.staff.unshift(s); await upsert('staff',s); render(); }
  async function saveWork(){ const staffId=$('staffSelect').value; const s=state.staff.find(x=>x.id===staffId); if(!s)return toast('Select staff'); const rate=Number($('rate').value||0), qty=Number($('workQty').value||1), paid=Number($('paidToday').value||0); const row={id:uid(),staffId,staffName:s.name,type:$('workType').value.trim(),rate,qty,earning:rate*qty,paid,date:today(),createdAt:nowISO()}; state.staffLedger.unshift(row); await upsert('staffLedger',row); render(); }

  function analytics(){ const revenue=state.orders.reduce((a,o)=>a+Number(o.advance||0)+Number(o.paidOnDelivery||0),0); const due=state.orders.reduce((a,o)=>a+Math.max(Number(o.total||0)-Number(o.advance||0)-Number(o.paidOnDelivery||0),0),0); const stitched=state.orders.filter(o=>['Ready','Delivered'].includes(o.status)).reduce((a,o)=>a+Number(o.qty||0),0); return layout(`<div class="grid">${metric('💰',money(revenue),'Revenue')}${metric('📌',money(due),'Total Due')}${metric('✅',stitched,'Stitched')}${metric('🚚',state.deliveries.reduce((a,d)=>a+Number(d.qty||0),0),'Delivered')}</div>`); }
  function settings(){ return layout(`<section class="card"><h3>Shop Info</h3><div class="form-grid"><input id="shopName" value="${esc(state.settings.shopName)}" placeholder="Shop name" /><input id="shopPhone" value="${esc(state.settings.phone)}" placeholder="Shop phone" /><textarea id="shopAddress" placeholder="Address">${esc(state.settings.address)}</textarea><button class="btn" id="saveSettingsBtn">Save Settings</button></div></section><section class="card"><h3>Measurements</h3><textarea id="measurementsText">${esc((state.settings.measurements||[]).join('\n'))}</textarea><p class="hint">One measurement label per line.</p></section><section class="card"><h3>Backup</h3><button class="btn secondary" id="exportBtn">Export JSON</button><textarea id="importJson" placeholder="Paste backup JSON to import"></textarea><button class="btn secondary" id="importBtn">Import JSON</button></section><section class="card danger-zone"><h3>Data Reset</h3><input id="confirmReset" placeholder="Type CONFIRM" /><button class="btn danger" id="resetBtn">Clear All Local Data</button></section>`); }
  async function saveSettingsFromForm(){ state.settings.shopName=$('shopName').value.trim()||"Tailor's ERP"; state.settings.phone=$('shopPhone').value.trim(); state.settings.address=$('shopAddress').value.trim(); state.settings.measurements=$('measurementsText').value.split('\n').map(x=>x.trim()).filter(Boolean); await saveSettings(); toast('Settings saved'); render(); }
  function exportData(){ const data={orders:state.orders,staff:state.staff,staffLedger:state.staffLedger,deliveries:state.deliveries,settings:state.settings,exportedAt:nowISO()}; navigator.clipboard?.writeText(JSON.stringify(data,null,2)); showModal(`<div class="modal-head"><h3>Backup JSON</h3><button class="icon-btn" data-close>×</button></div><textarea style="min-height:320px">${esc(JSON.stringify(data,null,2))}</textarea>`); }
  function importData(){ try{const data=JSON.parse($('importJson').value); state.orders=data.orders||[]; state.staff=data.staff||[]; state.staffLedger=data.staffLedger||[]; state.deliveries=data.deliveries||[]; state.settings={...DEFAULT_SETTINGS,...(data.settings||{})}; persistAll(); toast('Imported'); render();}catch{toast('Invalid backup JSON');} }
  function resetData(){ if($('confirmReset').value!=='CONFIRM')return toast('Type CONFIRM'); [LS.orders,LS.staff,LS.staffLedger,LS.deliveries].forEach(k=>localStorage.removeItem(k)); loadLocal(); toast('Local data cleared'); render(); }

  function showModal(html){ $('modal-root').innerHTML=`<div class="modal-wrap"><div class="modal">${html}</div></div>`; document.querySelectorAll('[data-close]').forEach(b=>b.onclick=closeModal); }
  function closeModal(){ $('modal-root').innerHTML=''; }
  function openWhatsapp(phone,text){ const url=`https://api.whatsapp.com/send?phone=${normalizePhone(phone).replace('+','')}&text=${encodeURIComponent(text)}`; window.open(url,'_blank','noopener'); }
  function printSlip(order){ const w=window.open('','_blank'); if(!w)return; const due=Number(order.total)-Number(order.advance); w.document.write(`<html><head><title>Slip ${esc(order.slip)}</title><style>body{font-family:Arial;padding:24px}h1{margin:0}.box{border:1px solid #ddd;padding:16px;border-radius:12px}table{width:100%;border-collapse:collapse}td{padding:8px;border-bottom:1px solid #eee}</style></head><body><div class="box"><h1>${esc(state.settings.shopName)}</h1><p>${esc(state.settings.address)}</p><h2>Slip #${esc(order.slip)}</h2><table><tr><td>Name</td><td>${esc(order.name)}</td></tr><tr><td>Mobile</td><td>${esc(order.mobile)}</td></tr><tr><td>Qty</td><td>${order.qty}</td></tr><tr><td>Total</td><td>${money(order.total)}</td></tr><tr><td>Advance</td><td>${money(order.advance)}</td></tr><tr><td>Due</td><td>${money(due)}</td></tr></table><h3>Measurements</h3><pre>${esc(JSON.stringify(order.measurements,null,2))}</pre><p>${esc(state.settings.slipText)}</p></div><script>window.print()</script></body></html>`); w.document.close(); }
  function callPhone(phone){ if(confirm(`Call customer ${phone}?`)) location.href=`tel:${normalizePhone(phone)}`; }
  function editOrder(id){ const o=state.orders.find(x=>x.id===id); if(!o)return; showModal(`<div class="modal-head"><h3>Edit Order #${esc(o.slip)}</h3><button class="icon-btn" data-close>×</button></div><div class="form-grid"><input id="editName" value="${esc(o.name)}" /><input id="editTotal" type="number" value="${o.total}" /><input id="editAdvance" type="number" value="${o.advance}" /><select id="editStatus"><option>Pending</option><option>Cutting</option><option>Ready</option><option>Delivered</option></select><button class="btn" id="saveEditBtn">Save Edit</button></div>`); $('editStatus').value=o.status; $('saveEditBtn').onclick=async()=>{o.name=$('editName').value.trim();o.total=Number($('editTotal').value||0);o.advance=Number($('editAdvance').value||0);o.status=$('editStatus').value;o.updatedAt=nowISO();await upsert('orders',o);closeModal();render();}; }

  function bind() {
    document.body.onclick = async (e) => {
      const nav=e.target.closest('[data-nav]'); if(nav) return setView(nav.dataset.nav);
      if(e.target.closest('#drawerBtn')) { state.drawer=true; return render(); }
      if(e.target.matches('[data-close-drawer]')) { state.drawer=false; return render(); }
      if(e.target.closest('#logoutBtn')) return logout();
      if(e.target.closest('#syncBtn')) { await syncDown(); toast('Synced'); return render(); }
      if(e.target.closest('#sendOtpBtn')) return sendOtp();
      if(e.target.closest('#setupFirebaseBtn')) return firebaseSetupModal();
      if(e.target.closest('#saveOrderBtn')) return saveOrder();
      if(e.target.closest('#addStaffBtn')) return addStaff();
      if(e.target.closest('#saveWorkBtn')) return saveWork();
      if(e.target.closest('#saveSettingsBtn')) return saveSettingsFromForm();
      if(e.target.closest('#exportBtn')) return exportData();
      if(e.target.closest('#importBtn')) return importData();
      if(e.target.closest('#resetBtn')) return resetData();
      const call=e.target.closest('[data-call]'); if(call) return callPhone(call.dataset.call);
      const edit=e.target.closest('[data-edit]'); if(edit) return editOrder(edit.dataset.edit);
      const slip=e.target.closest('[data-slip]'); if(slip){const o=state.orders.find(x=>x.id===slip.dataset.slip); if(o) return printSlip(o);}
      const st=e.target.closest('[data-status]'); if(st){const [id,status]=st.dataset.status.split(':'); return updateStatus(id,status);}
      const del=e.target.closest('[data-deliver]'); if(del)return confirmDelivery(del.dataset.deliver);
    };
    document.body.oninput = (e) => {
      if(e.target.id==='quickSearch'){state.search=e.target.value; render();}
      if(['total','advance'].includes(e.target.id)){ const total=Number($('total')?.value||0); const adv=Number($('advance')?.value||0); const d=$('duePreview'); if(d)d.textContent=money(Math.max(total-adv,0)); }
    };
  }

  function render() {
    try {
      if (!state.user) { app().innerHTML = authScreen(); return; }
      const map={dashboard,orders:orderForm,processing,delivery,staff:staffView,analytics,settings};
      app().innerHTML = (map[state.view] || dashboard)();
    } catch (err) {
      console.error(err); app().innerHTML = `<main class="auth-page"><section class="auth-card"><h1>Startup Protected</h1><div class="error">${esc(err.message||err)}</div><button class="btn" onclick="location.reload()">Reload</button></section></main>`;
    }
  }
  async function init() {
    bind(); loadLocal(); render(); await initFirebase();
    if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js').catch(()=>null);
    setInterval(()=>{ if(state.user && ['Owner','Manager'].includes(state.user.role)){ const login = new Date(state.user.loginAt).getTime(); if(Date.now()-login>20*60*1000){ toast('Session expired'); logout(); } } }, 30000);
  }
  return { init };
})();

document.addEventListener('DOMContentLoaded', App.init);
