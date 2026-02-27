(function() {
  console.log('[Search] Initializing custom search');
  
  setTimeout(() => {
    const targetContainer = document.getElementById('information-widgets-right') ||
                            document.querySelector('main') ||
                            document.querySelector('[class*="container"]') ||
                            document.body;

    console.log('[Search] Target container found:', targetContainer.id || targetContainer.tagName);
    
    const searchContainer = document.createElement('div');
    searchContainer.id = 'custom-search-container';
    
    const searchInput = document.createElement('input');
    searchInput.id = 'custom-search-input';
    searchInput.type = 'text';
    searchInput.placeholder = 'Search the web...';
    searchInput.autocomplete = 'off';
    searchInput.autocapitalize = 'none';
    searchInput.autocorrect = 'off';
    
    const suggestionsBox = document.createElement('div');
    suggestionsBox.id = 'search-suggestions';
    suggestionsBox.style.display = 'none';
    
    searchContainer.appendChild(searchInput);
    searchContainer.appendChild(suggestionsBox);
    targetContainer.insertBefore(searchContainer, targetContainer.firstChild);
    
    console.log('[Search] Custom search DOM injected');
    
    let debounceTimer;
    let currentSuggestions = [];
    let selectedIndex = -1;
    
    searchInput.addEventListener('input', function(e) {
      const query = e.target.value.trim();
      console.log('[Search] Input event, query:', query);
      
      clearTimeout(debounceTimer);
      
      if (query.length < 2) {
        suggestionsBox.style.display = 'none';
        return;
      }
      
      debounceTimer = setTimeout(() => {
        console.log('[Search] Debounce complete, fetching suggestions');
        fetchSuggestions(query);
      }, 200);
    });
    
    searchInput.addEventListener('keydown', function(e) {
      const items = suggestionsBox.querySelectorAll('.suggestion-item');
      
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (items.length > 0) {
          selectedIndex = Math.min(selectedIndex + 1, items.length - 1);
          console.log('[Search] Arrow down, selectedIndex:', selectedIndex);
          updateSelection(items);
        }
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (items.length > 0) {
          selectedIndex = Math.max(selectedIndex - 1, -1);
          console.log('[Search] Arrow up, selectedIndex:', selectedIndex);
          updateSelection(items);
        }
      } else if (e.key === 'Enter') {
        e.preventDefault();
        
        let searchQuery;
        if (selectedIndex >= 0 && currentSuggestions[selectedIndex]) {
          searchQuery = currentSuggestions[selectedIndex];
          console.log('[Search] Enter pressed with selection:', searchQuery);
        } else {
          searchQuery = searchInput.value.trim();
          console.log('[Search] Enter pressed, direct input:', searchQuery);
        }
        
        if (searchQuery) {
          const url = `http://4get.home/web?s=${encodeURIComponent(searchQuery)}`;
          console.log('[Search] Navigating to:', url);
          window.location.href = url;
        }
      } else if (e.key === 'Escape') {
        console.log('[Search] Escape pressed, hiding suggestions');
        suggestionsBox.style.display = 'none';
        selectedIndex = -1;
      }
    });
    
    function updateSelection(items) {
      items.forEach((item, index) => {
        if (index === selectedIndex) {
          item.classList.add('selected');
          searchInput.value = currentSuggestions[index];
        } else {
          item.classList.remove('selected');
        }
      });
    }
    
    async function fetchSuggestions(query) {
      try {
	const url = `http://4get.home/api/v1/ac?s=${encodeURIComponent(query)}`;
	
        console.log('[Search] Fetching:', url);
	const response = await fetch(url, {
	    credentials: 'omit'
	});

        const data = await response.json();
        console.log('[Search] Response received:', data);
        
        const suggestions = data[1] || [];
        currentSuggestions = suggestions;
        console.log('[Search] Parsed suggestions:', suggestions.length, 'items');
        
        if (suggestions.length > 0) {
          displaySuggestions(suggestions);
        } else {
          suggestionsBox.style.display = 'none';
        }
      } catch (error) {
        console.error('[Search] Fetch error:', error);
        suggestionsBox.style.display = 'none';
      }
    }
    
    function displaySuggestions(suggestions) {
      console.log('[Search] Displaying suggestions');
      suggestionsBox.innerHTML = '';
      selectedIndex = -1;
      
      suggestions.slice(0, 8).forEach((suggestion, index) => {
        const item = document.createElement('div');
        item.className = 'suggestion-item';
        item.textContent = suggestion;
        
        item.addEventListener('click', function(e) {
          e.preventDefault();
          const url = `http://4get.home/search?s=${encodeURIComponent(suggestion)}`;
          console.log('[Search] Suggestion clicked, navigating to:', url);
          window.location.href = url;
        });
        
        item.addEventListener('mouseenter', function() {
          selectedIndex = index;
          updateSelection(suggestionsBox.querySelectorAll('.suggestion-item'));
        });
        
        suggestionsBox.appendChild(item);
      });
      
      suggestionsBox.style.display = 'block';
      console.log('[Search] Suggestions box displayed');
    }
    
    document.addEventListener('click', function(e) {
      if (!searchContainer.contains(e.target)) {
        suggestionsBox.style.display = 'none';
        selectedIndex = -1;
      }
    });
    
    searchInput.focus();
    console.log('[Search] Initialization complete');
  }, 500);
})();
