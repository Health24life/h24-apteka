// ES Module version for ActiveAdmin 4+ with esbuild/webpack
// Tom Select version - no jQuery dependency required
import TomSelect from 'tom-select';

const MODULE_NAME = 'ActiveAdmin Searchable Select';
const SELECTOR = '.searchable-select-input, .tom-select-input';
const INITIALIZED_CLASS = 'tom-select-initialized';

// Core initialization function
export function initSearchableSelects(inputs, extra) {
  if (!inputs || inputs.length === 0) return;
  
  // Handle both NodeList and array of elements
  const elements = inputs instanceof NodeList ? Array.from(inputs) : 
                   inputs.length !== undefined ? inputs : [inputs];
  
  elements.forEach(element => {
    // Skip if already initialized
    if (element.classList.contains(INITIALIZED_CLASS)) return;
    
    // Mark as initialized
    element.classList.add(INITIALIZED_CLASS);
    
    // Get options from data attributes
    const dataOptions = element.dataset.searchableSelect ? 
                       JSON.parse(element.dataset.searchableSelect) : {};
    
    // Merge with extra options
    const options = Object.assign({}, extra || {}, dataOptions);
    
    // Configure AJAX if URL is provided
    const ajaxUrl = element.dataset.ajaxUrl;
    if (ajaxUrl) {
      // Configure virtual scroll for pagination
      options.plugins = options.plugins || [];
      if (!options.plugins.includes('virtual_scroll')) {
        options.plugins.push('virtual_scroll');
      }
      
      // Set max options for virtual scroll
      options.maxOptions = options.maxOptions || 200;
      
      // Configure the first URL for pagination
      options.firstUrl = function(query) {
        const url = new URL(ajaxUrl, window.location.href);
        url.searchParams.set('term', query);
        url.searchParams.set('page', 1);
        return url.toString();
      };
      
      // Main load function with pagination support
      options.load = function(query, callback) {
        // Get the appropriate URL (either first or next)
        const url = this.getUrl(query);
        
        fetch(url)
          .then(response => response.json())
          .then(json => {
            // Handle pagination info if present
            if (json.pagination && json.pagination.more) {
              // Set up the next URL for virtual scroll (1-based pagination)
              const nextUrl = new URL(ajaxUrl, window.location.href);
              nextUrl.searchParams.set('term', query);
              // Backend now uses 1-based pagination and returns current page
              const nextPage = (json.pagination.current || 1) + 1;
              nextUrl.searchParams.set('page', nextPage);
              this.setNextUrl(query, nextUrl.toString());
            }
            
            callback(json.results || json);
          })
          .catch(() => callback());
      };
      
      // Map Select2-style options to Tom Select
      options.valueField = options.valueField || 'id';
      options.labelField = options.labelField || 'text';
      options.searchField = options.searchField || ['text'];
      
      // Enable remote loading features
      options.preload = options.preload !== false ? 'focus' : false;
      options.loadThrottle = options.loadThrottle || 300;
    }
    
    // Handle placeholder
    if (element.placeholder) {
      options.placeholder = element.placeholder;
    }
    
    // Check if element should be clearable (default to true for searchable selects)
    const isClearable = element.dataset.clearable !== 'false';
    
    // Map common Select2 options to Tom Select equivalents
    if (options.allowClear || isClearable) {
      // Don't add empty option - we use clear_button plugin instead
      // options.allowEmptyOption = true;
      
      // Add clear_button plugin (make sure plugins array exists)
      options.plugins = options.plugins || [];
      if (!options.plugins.includes('clear_button')) {
        options.plugins.push('clear_button');
      }
    }
    
    if (options.minimumInputLength) {
      options.shouldLoad = function(query) {
        return query.length >= options.minimumInputLength;
      };
    }
    
    // Initialize Tom Select
    new TomSelect(element, options);
  });
}

// Auto-initialize on common events  
export function setupAutoInit() {
  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      initSearchableSelects(document.querySelectorAll(SELECTOR));
    });
  } else {
    initSearchableSelects(document.querySelectorAll(SELECTOR));
  }

  // Support Turbo (Rails 7+)
  document.addEventListener('turbo:load', function() {
    initSearchableSelects(document.querySelectorAll(`${SELECTOR}:not(.${INITIALIZED_CLASS})`));
  });

  // ActiveAdmin 4 uses .has-many-add button click for dynamic content
  document.addEventListener('click', function(event) {
    if (event.target.closest('.has-many-add')) {
      setTimeout(function() {
        initSearchableSelects(
          document.querySelectorAll(`${SELECTOR}:not(.${INITIALIZED_CLASS})`)
        );
      }, 10);
    }
  });
  
  // Support has_many_add:after event (ActiveAdmin specific)
  document.addEventListener('has_many_add:after', function(event) {
    const fieldset = event.detail || event.target;
    if (fieldset) {
      const selects = fieldset.querySelectorAll(`${SELECTOR}:not(.${INITIALIZED_CLASS})`);
      initSearchableSelects(selects);
    }
  });
}