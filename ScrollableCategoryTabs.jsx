import React, { useState, useRef, useEffect, useCallback } from 'react';

const ScrollableCategoryTabs = ({
  categories,
  selected,
  onSelect,
  ariaLabel = 'Category tabs'
}) => {
  // State management
  const [internalSelected, setInternalSelected] = useState(categories[0] || '');
  const [showLeftChevron, setShowLeftChevron] = useState(false);
  const [showRightChevron, setShowRightChevron] = useState(false);
  const [isDragging, setIsDragging] = useState(false);

  // Refs
  const containerRef = useRef(null);
  const tabsRef = useRef([]);

  // Derived state
  const selectedCategory = selected ?? internalSelected;
  const isControlled = selected !== undefined;

  // Helper: Check if tab is fully visible using getBoundingClientRect()
  const isFullyVisible = useCallback((tabEl) => {
    const container = containerRef.current;
    if (!container || !tabEl) return false;

    const containerRect = container.getBoundingClientRect();
    const tabRect = tabEl.getBoundingClientRect();

    // Account for container padding and ensure whole tab is visible horizontally
    const containerLeft = containerRect.left + parseFloat(getComputedStyle(container).paddingLeft);
    const containerRight = containerRect.right - parseFloat(getComputedStyle(container).paddingRight);

    return (
      tabRect.left >= containerLeft &&
      tabRect.right <= containerRight
    );
  }, []);

  // Helper: Find last fully visible tab index
  const findLastFullyVisibleIndex = useCallback(() => {
    const container = containerRef.current;
    if (!container) return -1;

    let lastVisibleIndex = -1;
    tabsRef.current.forEach((tab, index) => {
      if (tab && isFullyVisible(tab)) {
        lastVisibleIndex = index;
      }
    });

    return lastVisibleIndex;
  }, [isFullyVisible]);

  // Helper: Ensure tab is visible with smart auto-scroll behavior
  const ensureTabVisible = useCallback((index) => {
    const tab = tabsRef.current[index];
    if (!tab || !containerRef.current) return;

    const lastVisibleIndex = findLastFullyVisibleIndex();
    const isFirstVisible = index === 0;
    const isLastFullyVisible = index === lastVisibleIndex;

    if (isFirstVisible) {
      // If clicking first tab that might be partially visible, scroll to show it
      tab.scrollIntoView({ behavior: 'smooth', inline: 'start' });
    } else if (isLastFullyVisible && index < categories.length - 1) {
      // If clicking last fully visible tab, auto-scroll to bring next tabs into view
      const nextTabIndex = Math.min(index + 1, categories.length - 1);
      const nextTab = tabsRef.current[nextTabIndex];
      if (nextTab) {
        nextTab.scrollIntoView({ behavior: 'smooth', inline: 'center' });
      }
    } else {
      // For other cases, center the clicked tab for optimal visibility
      tab.scrollIntoView({ behavior: 'smooth', inline: 'center' });
    }
  }, [categories.length, findLastFullyVisibleIndex]);

  // Handle tab selection with auto-scroll
  const handleTabClick = useCallback((category, index) => {
    // Don't trigger if user is actively dragging
    if (isDragging) return;

    // Update selected state
    if (!isControlled) {
      setInternalSelected(category);
    }
    onSelect?.(category);

    // Implement smart auto-scroll behavior
    ensureTabVisible(index);
  }, [ensureTabVisible, isControlled, isDragging, onSelect]);

  // Keyboard navigation with arrow keys and Home/End
  const handleKeyDown = useCallback((e, index) => {
    let newIndex = index;

    switch (e.key) {
      case 'ArrowRight':
        e.preventDefault();
        newIndex = Math.min(index + 1, categories.length - 1);
        break;
      case 'ArrowLeft':
        e.preventDefault();
        newIndex = Math.max(index - 1, 0);
        break;
      case 'Home':
        e.preventDefault();
        newIndex = 0;
        break;
      case 'End':
        e.preventDefault();
        newIndex = categories.length - 1;
        break;
      default:
        return;
    }

    // Focus the new tab and ensure it's visible
    const newTab = tabsRef.current[newIndex];
    if (newTab) {
      newTab.focus();
      handleTabClick(categories[newIndex], newIndex);
    }
  }, [categories, handleTabClick]);

  // Manual scroll handlers for chevron buttons
  const scrollLeft = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const scrollAmount = container.clientWidth * 0.8; // Scroll 80% of visible width
    container.scrollBy({ left: -scrollAmount, behavior: 'smooth' });
  }, []);

  const scrollRight = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const scrollAmount = container.clientWidth * 0.8; // Scroll 80% of visible width
    container.scrollBy({ left: scrollAmount, behavior: 'smooth' });
  }, []);

  // Touch drag detection to prevent false auto-scroll triggers
  const handleTouchStart = useCallback(() => {
    setIsDragging(false);
  }, []);

  const handleTouchMove = useCallback(() => {
    setIsDragging(true);
  }, []);

  const handleTouchEnd = useCallback(() => {
    // Small delay to reset dragging state after touch ends
    setTimeout(() => setIsDragging(false), 100);
  }, []);

  // Update chevron visibility based on scroll position and overflow
  const updateChevronVisibility = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const hasOverflow = container.scrollWidth > container.clientWidth;
    const canScrollLeft = container.scrollLeft > 5; // Small threshold
    const canScrollRight = container.scrollLeft < container.scrollWidth - container.clientWidth - 5;

    setShowLeftChevron(hasOverflow && canScrollLeft);
    setShowRightChevron(hasOverflow && canScrollRight);
  }, []);

  // Setup resize observer and scroll event listeners for performance
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    // Initial chevron visibility check
    updateChevronVisibility();

    // Setup ResizeObserver for responsive behavior
    let resizeObserver = null;
    if (typeof ResizeObserver !== 'undefined') {
      resizeObserver = new ResizeObserver(() => {
        // Debounce with requestAnimationFrame for performance
        requestAnimationFrame(updateChevronVisibility);
      });
      resizeObserver.observe(container);
    }

    // Scroll event listener with passive: true for better performance
    const handleScroll = () => {
      requestAnimationFrame(updateChevronVisibility);
    };

    container.addEventListener('scroll', handleScroll, { passive: true });

    // Window resize listener with debouncing
    const handleResize = () => {
      clearTimeout(handleResize.timeoutId);
      handleResize.timeoutId = setTimeout(() => {
        requestAnimationFrame(updateChevronVisibility);
      }, 150); // 150ms debounce
    };

    window.addEventListener('resize', handleResize);

    // Cleanup function
    return () => {
      resizeObserver?.disconnect();
      container.removeEventListener('scroll', handleScroll);
      window.removeEventListener('resize', handleResize);
      clearTimeout(handleResize.timeoutId);
    };
  }, [updateChevronVisibility]);

  // Cleanup refs when component unmounts
  useEffect(() => {
    return () => {
      tabsRef.current = [];
    };
  }, []);

  return (
    <div className="relative">
      {/* Left chevron button - appears when scrolling left is possible */}
      {showLeftChevron && (
        <button
          onClick={scrollLeft}
          className="absolute left-0 top-1/2 -translate-y-1/2 z-10 bg-white shadow-md rounded-full p-2
                     hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-orange-400
                     transition-all duration-200 border border-gray-200"
          aria-label="Scroll left"
        >
          <svg
            className="w-4 h-4 text-gray-600"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
      )}

      {/* Right chevron button - appears when scrolling right is possible */}
      {showRightChevron && (
        <button
          onClick={scrollRight}
          className="absolute right-0 top-1/2 -translate-y-1/2 z-10 bg-white shadow-md rounded-full p-2
                     hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-orange-400
                     transition-all duration-200 border border-gray-200"
          aria-label="Scroll right"
        >
          <svg
            className="w-4 h-4 text-gray-600"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
      )}

      {/* Left gradient overlay - indicates more content on left */}
      <div
        className={`absolute left-0 top-0 bottom-0 w-8 z-0 pointer-events-none
                   bg-gradient-to-r from-white to-transparent transition-opacity duration-200
                   ${showLeftChevron ? 'opacity-100' : 'opacity-0'}`}
      />

      {/* Right gradient overlay - indicates more content on right */}
      <div
        className={`absolute right-0 top-0 bottom-0 w-8 z-0 pointer-events-none
                   bg-gradient-to-l from-white to-transparent transition-opacity duration-200
                   ${showRightChevron ? 'opacity-100' : 'opacity-0'}`}
      />

      {/* Main tab container with horizontal scrolling */}
      <div
        ref={containerRef}
        role="tablist"
        aria-label={ariaLabel}
        className="relative overflow-x-auto overflow-y-hidden scrollbar-hide
                   bg-white rounded-lg"
        style={{
          scrollbarWidth: 'none',
          msOverflowStyle: 'none',
          WebkitOverflowScrolling: 'touch' // Enable momentum scrolling on iOS
        }}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
      >
        <div className="flex gap-2 px-4 py-3 min-w-max">
          {categories.map((category, index) => (
            <button
              key={`${category}-${index}`}
              ref={(el) => (tabsRef.current[index] = el)}
              role="tab"
              aria-selected={selectedCategory === category}
              aria-controls={`tabpanel-${index}`}
              tabIndex={selectedCategory === category ? 0 : -1}
              onClick={() => handleTabClick(category, index)}
              onKeyDown={(e) => handleKeyDown(e, index)}
              className={`relative px-3 py-1.5 rounded-full text-sm font-medium
                         transition-all duration-200 ease-out
                         focus:outline-none focus:ring-2 focus:ring-orange-400 focus:ring-offset-2
                         active:scale-95 whitespace-nowrap select-none
                         ${
                           selectedCategory === category
                             ? 'bg-orange-500 text-white shadow-md hover:bg-orange-600'
                             : 'bg-gray-100 text-gray-700 hover:bg-gray-200 focus:bg-gray-200'
                         }`}
            >
              {category}
            </button>
          ))}
        </div>

        {/* Hide scrollbar for Webkit browsers */}
        <style jsx>{`
          .scrollbar-hide::-webkit-scrollbar {
            display: none;
          }
        `}</style>
      </div>
    </div>
  );
};

export default ScrollableCategoryTabs;