<script>
  export let value = '';
  export let placeholder = 'z.B. Marzili, Bern';

  let suggestions  = [];
  let showDropdown = false;
  let loading      = false;
  let debounceTimer;

  function formatSuggestion(item) {
    const a       = item.address ?? {};
    const city    = a.city || a.town || a.village || a.hamlet || a.suburb || a.municipality;
    const district = a.city_district || a.suburb;
    const country  = (a.country_code ?? '').toUpperCase();
    const DACH     = ['DE','AT','CH'].includes(country);

    if (district && city && district !== city)
      return DACH ? `${district}, ${city}` : `${district}, ${city}, ${a.country}`;
    if (city)
      return DACH ? city : `${city}, ${a.country}`;
    return item.display_name.split(',').slice(0, 2).join(',').trim();
  }

  async function fetchSuggestions(q) {
    if (q.length < 2) { suggestions = []; showDropdown = false; return; }
    loading = true;
    try {
      const res  = await fetch(
        `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)}&format=json&limit=6&addressdetails=1&accept-language=de`
      );
      const data = await res.json();
      const seen = new Set();
      suggestions = data
        .map(item => formatSuggestion(item))
        .filter(label => { if (seen.has(label)) return false; seen.add(label); return true; });
      showDropdown = suggestions.length > 0;
    } catch { suggestions = []; }
    loading = false;
  }

  function onInput(e) {
    value = e.target.value;
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => fetchSuggestions(value), 350);
  }

  function select(label) {
    value        = label;
    showDropdown = false;
    suggestions  = [];
  }

  function onBlur()  { setTimeout(() => { showDropdown = false; }, 160); }
  function onKeydown(e) { if (e.key === 'Escape') showDropdown = false; }
</script>

<div style="position:relative;">
  <input
    class="input"
    type="text"
    {placeholder}
    bind:value
    on:input={onInput}
    on:blur={onBlur}
    on:keydown={onKeydown}
    autocomplete="off"
  />

  {#if loading}
    <span class="spinner">⟳</span>
  {/if}

  {#if showDropdown && suggestions.length > 0}
    <ul class="dropdown">
      {#each suggestions as label}
        <li>
          <button
            type="button"
            class="suggestion"
            on:mousedown|preventDefault={() => select(label)}
          >
            <span class="pin">·</span>
            {label}
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .spinner {
    position: absolute;
    right: 0.9rem;
    top: 50%;
    transform: translateY(-50%);
    font-size: 0.9rem;
    color: var(--text-muted);
    animation: spin 0.7s linear infinite;
    pointer-events: none;
  }

  .dropdown {
    position: absolute;
    top: calc(100% + 4px);
    left: 0; right: 0;
    z-index: 60;
    background: white;
    border: 2px solid var(--border);
    border-radius: var(--radius-sm);
    box-shadow: var(--shadow-hover);
    list-style: none;
    padding: 0.25rem 0;
    margin: 0;
    overflow: hidden;
  }

  .suggestion {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.55rem 0.85rem;
    background: none;
    border: none;
    cursor: pointer;
    font-family: var(--font-body);
    font-size: 0.95rem;
    color: var(--text);
    text-align: left;
    transition: background 0.1s;
  }
  .suggestion:hover { background: var(--bg); }

  .pin {
    color: var(--primary);
    font-size: 1.2rem;
    line-height: 1;
    flex-shrink: 0;
  }

  @keyframes spin { to { transform: translateY(-50%) rotate(360deg); } }
</style>
