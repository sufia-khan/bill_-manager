import React, { useState, useRef, useEffect, useCallback } from 'react';

interface ScrollableCategoryTabsProps {
  categories: string[];
  selected?: string;
  onSelect?: (category: string) => void;
  ariaLabel?: string;
}

const ScrollableCategoryTabs: React.FC<ScrollableCategoryTabsProps> = ({
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
  const containerRef = useRef<HTMLDivElement>(null);
  const tabsRef = useRef<(HTMLButtonElement | null)[]>([]);

  // Derived state
  const selectedCategory = selected ?? internalSelected;
  const isControlled = selected !== undefined;

  // Helper: Check if tab is fully visible
  const isFullyVisible = useCallback((tabEl: HTMLElement): boolean => {
    const container = containerRef.current;
    if (!container || !tabEl) return false;

    const containerRect = container.getBoundingClientRect();
    const tabRect = tabEl.getBoundingClientRect();

    return (
      tabRect.left >= containerRect.left &&
      tabRect.right <= containerRect.right
    );
  }, []);

  // Helper: Find last fully visible tab index
  const findLastFullyVisibleIndex = useCallback((): number => {
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

  // Helper: Ensure tab is visible with auto-scroll behavior
  const ensureTabVisible = useCallback((index: number) => {
    const tab = tabsRef.current[index];
    if (!tab || !containerRef.current) return;

    const lastVisibleIndex = findLastFullyVisibleIndex();
    const isFirstVisible = index === 0;
    const isLastFullyVisible = index === lastVisibleIndex;

    if (isFirstVisible) {
      // If clicking first tab that's partially visible, scroll to show it
      tab.scrollIntoView({ behavior: 'smooth', inline: 'start' });
    } else if (isLastFullyVisible && index < categories.length - 1) {
      // If clicking last fully visible tab, scroll to bring next tabs into view
      const nextTabIndex = Math.min(index + 1, categories.length - 1);
      const nextTab = tabsRef.current[nextTabIndex];
      if (nextTab) {
        nextTab.scrollIntoView({ behavior: 'smooth', inline: 'center' });
      }
    } else {
      // For other cases, center the clicked tab
      tab.scrollIntoView({ behavior: 'smooth', inline: 'center' });
    }
  }, [categories.length, findLastFullyVisibleIndex]);

  // Handle tab selection
  const handleTabClick = useCallback((category: string, index: number) => {
    // Update selected state
    if (!isControlled) {
      setInternalSelected(category);
    }
    onSelect?.(category);

    // Auto-scroll behavior
    ensureTabVisible(index);
  }, [ensureTabVisible, isControlled, onSelect]);

  // Keyboard navigation
  const handleKeyDown = useCallback((e: React.KeyboardEvent<HTMLButtonElement>, index: number) => {
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

    // Focus the new tab
    const newTab = tabsRef.current[newIndex];
    if (newTab) {
      newTab.focus();
      handleTabClick(categories[newIndex], newIndex);
    }
  }, [categories, handleTabClick]);

  // Scroll handlers for chevrons
  const scrollLeft = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const scrollAmount = container.clientWidth * 0.8;
    container.scrollBy({ left: -scrollAmount, behavior: 'smooth' });
  }, []);

  const scrollRight = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const scrollAmount = container.clientWidth * 0.8;
    container.scrollBy({ left: scrollAmount, behavior: 'smooth' });
  }, []);

  // Touch drag detection
  const handleTouchStart = useCallback(() => {
    setIsDragging(false);
  }, []);

  const handleTouchMove = useCallback(() => {
    setIsDragging(true);
  }, []);

  const handleTouchEnd = useCallback(() => {
    // Small delay to reset dragging state
    setTimeout(() => setIsDragging(false), 100);
  }, []);

  // Update chevron visibility
  const updateChevronVisibility = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const hasOverflow = container.scrollWidth > container.clientWidth;
    const canScrollLeft = container.scrollLeft > 0;
    const canScrollRight = container.scrollLeft < container.scrollWidth - container.clientWidth;

    setShowLeftChevron(hasOverflow && canScrollLeft);
    setShowRightChevron(hasOverflow && canScrollRight);
  }, []);

  // Setup resize observer and scroll event listeners
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    // Initial check
    updateChevronVisibility();

    // Setup ResizeObserver for responsive behavior
    let resizeObserver: ResizeObserver | null = null;
    if (typeof ResizeObserver !== 'undefined') {
      resizeObserver = new ResizeObserver(() => {
        // Debounce with requestAnimationFrame for performance
        requestAnimationFrame(updateChevronVisibility);
      });
      resizeObserver.observe(container);
    }

    // Scroll event listener (with passive: true for performance)
    const handleScroll = () => {
      requestAnimationFrame(updateChevronVisibility);
    };

    container.addEventListener('scroll', handleScroll, { passive: true });

    // Window resize listener (debounced)
    const handleResize = () => {
      clearTimeout((handleResize as any).timeoutId);
      (handleResize as any).timeoutId = setTimeout(() => {
        requestAnimationFrame(updateChevronVisibility);
      }, 150);
    };

    window.addEventListener('resize', handleResize);

    // Cleanup
    return () => {
      resizeObserver?.disconnect();
      container.removeEventListener('scroll', handleScroll);
      window.removeEventListener('resize', handleResize);
      clearTimeout((handleResize as any).timeoutId);
    };
  }, [updateChevronVisibility]);

  // Cleanup refs on unmount
  useEffect(() => {
    return () => {
      tabsRef.current = [];
    };
  }, []);

  return (
    <div className="relative">
      {/* Left chevron */}
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

      {/* Right chevron */}
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

      {/* Left gradient overlay */}
      <div
        className={`absolute left-0 top-0 bottom-0 w-8 z-0 pointer-events-none
                   bg-gradient-to-r from-white to-transparent transition-opacity duration-200
                   ${showLeftChevron ? 'opacity-100' : 'opacity-0'}`}
      />

      {/* Right gradient overlay */}
      <div
        className={`absolute right-0 top-0 bottom-0 w-8 z-0 pointer-events-none
                   bg-gradient-to-l from-white to-transparent transition-opacity duration-200
                   ${showRightChevron ? 'opacity-100' : 'opacity-0'}`}
      />

      {/* Tab container */}
      <div
        ref={containerRef}
        role="tablist"
        aria-label={ariaLabel}
        className="relative overflow-x-auto overflow-y-hidden scrollbar-hide
                   bg-white rounded-lg"
        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
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
              onClick={() => !isDragging && handleTabClick(category, index)}
              onKeyDown={(e) => handleKeyDown(e, index)}
              className={`relative px-3 py-1.5 rounded-full text-sm font-medium
                         transition-all duration-200 ease-out
                         focus:outline-none focus:ring-2 focus:ring-orange-400 focus:ring-offset-2
                         active:scale-95 whitespace-nowrap
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