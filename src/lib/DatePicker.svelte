<script>
  import { onMount } from 'svelte';

  export let value = '';        // German display string "Sa, 14. Juni"
  export let placeholder = 'Datum wählen';

  const WEEKDAYS = ['Mo','Di','Mi','Do','Fr','Sa','So'];
  const MONTHS   = ['Januar','Februar','März','April','Mai','Juni',
                    'Juli','August','September','Oktober','November','Dezember'];
  const DAYS_SHORT = ['So','Mo','Di','Mi','Do','Fr','Sa'];

  let open       = false;
  let wrapEl;

  // Calendar state
  const today    = new Date();
  let viewYear   = today.getFullYear();
  let viewMonth  = today.getMonth(); // 0-based

  // Selected date
  let selYear  = null;
  let selMonth = null;
  let selDay   = null;

  function formatGerman(y, m, d) {
    const date = new Date(y, m, d);
    return `${DAYS_SHORT[date.getDay()]}, ${d}. ${MONTHS[m]}`;
  }

  function daysInMonth(y, m) {
    return new Date(y, m + 1, 0).getDate();
  }

  // Returns weekday offset Mon=0 … Sun=6
  function firstDayOffset(y, m) {
    const dow = new Date(y, m, 1).getDay(); // Sun=0
    return dow === 0 ? 6 : dow - 1;
  }

  $: cells = (() => {
    const offset = firstDayOffset(viewYear, viewMonth);
    const total  = daysInMonth(viewYear, viewMonth);
    const arr    = [];
    for (let i = 0; i < offset; i++) arr.push(null);
    for (let d = 1; d <= total; d++) arr.push(d);
    return arr;
  })();

  function prevMonth() {
    if (viewMonth === 0) { viewMonth = 11; viewYear--; }
    else viewMonth--;
  }
  function nextMonth() {
    if (viewMonth === 11) { viewMonth = 0; viewYear++; }
    else viewMonth++;
  }

  function selectDay(d) {
    if (!d) return;
    selYear  = viewYear;
    selMonth = viewMonth;
    selDay   = d;
    value    = formatGerman(selYear, selMonth, selDay);
    open     = false;
  }

  function clear(e) {
    e.stopPropagation();
    selYear = selMonth = selDay = null;
    value   = '';
  }

  function toggle() { open = !open; }

  function isToday(d) {
    return d === today.getDate() && viewMonth === today.getMonth() && viewYear === today.getFullYear();
  }
  function isSelected(d) {
    return d === selDay && viewMonth === selMonth && viewYear === selYear;
  }

  // Close on outside click
  function onDocClick(e) {
    if (open && wrapEl && !wrapEl.contains(e.target)) open = false;
  }
  onMount(() => {
    document.addEventListener('mousedown', onDocClick);
    return () => document.removeEventListener('mousedown', onDocClick);
  });
</script>

<div bind:this={wrapEl} style="position:relative;">
  <!-- Trigger field -->
  <div
    class="input"
    style="display:flex; align-items:center; gap:0.5rem; cursor:pointer; user-select:none; min-height:44px; flex-wrap:nowrap;"
    on:click={toggle}
    role="button"
    tabindex="0"
    on:keydown={e => (e.key === 'Enter' || e.key === ' ') && toggle()}
  >
    <span style="flex:1; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; color:{value ? 'var(--text)' : '#C4B9B1'}; font-size:1rem;">
      {value || placeholder}
    </span>
    {#if value}
      <button
        style="background:none; border:none; cursor:pointer; color:var(--text-muted); font-size:0.85rem; padding:0 0.1rem; line-height:1; flex-shrink:0;"
        on:click={clear}
        title="Löschen"
      >✕</button>
    {:else}
      <span style="color:var(--text-muted); font-size:0.8rem; flex-shrink:0; opacity:0.6;">▾</span>
    {/if}
  </div>

  <!-- Calendar popup -->
  {#if open}
    <div style="
      position:absolute; top:calc(100% + 6px); left:0; z-index:60;
      background:white; border:2px solid var(--border); border-radius:var(--radius);
      box-shadow:var(--shadow-hover); padding:1rem;
      min-width:260px;
    ">
      <!-- Month nav -->
      <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:0.75rem;">
        <button class="nav-btn" on:click={prevMonth}>‹</button>
        <span style="font-family:var(--font-hand); font-size:1.25rem; font-weight:600; color:var(--text);">
          {MONTHS[viewMonth]} {viewYear}
        </span>
        <button class="nav-btn" on:click={nextMonth}>›</button>
      </div>

      <!-- Weekday headers -->
      <div class="cal-grid">
        {#each WEEKDAYS as wd}
          <span style="font-size:0.72rem; font-weight:700; color:var(--text-muted); text-align:center; padding-bottom:0.3rem;">
            {wd}
          </span>
        {/each}

        <!-- Day cells -->
        {#each cells as d}
          {#if d === null}
            <span></span>
          {:else}
            <button
              class="day-btn"
              class:today={isToday(d)}
              class:selected={isSelected(d)}
              on:click={() => selectDay(d)}
            >{d}</button>
          {/if}
        {/each}
      </div>
    </div>
  {/if}
</div>

<style>
  .cal-grid {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 2px;
  }

  .nav-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 1.3rem;
    color: var(--text-muted);
    padding: 0.1rem 0.5rem;
    border-radius: var(--radius-sm);
    line-height: 1;
    transition: background 0.1s, color 0.1s;
  }
  .nav-btn:hover {
    background: var(--bg);
    color: var(--primary);
  }

  .day-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 0.88rem;
    font-family: var(--font-body);
    color: var(--text);
    border-radius: 6px;
    padding: 0.3rem 0;
    text-align: center;
    transition: background 0.1s, color 0.1s;
    width: 100%;
  }
  .day-btn:hover {
    background: var(--bg);
    color: var(--primary);
  }
  .day-btn.today {
    font-weight: 800;
    color: var(--primary);
  }
  .day-btn.selected {
    background: var(--primary);
    color: white;
    font-weight: 700;
  }
  .day-btn.selected:hover {
    background: var(--primary-dark);
    color: white;
  }
</style>
