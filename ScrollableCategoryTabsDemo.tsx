import React, { useState } from 'react';
import ScrollableCategoryTabs from './ScrollableCategoryTabs';

const ScrollableCategoryTabsDemo: React.FC = () => {
  // Sample categories - works with 20+ categories
  const categories = [
    'All',
    'Utilities',
    'Subscriptions',
    'Rent',
    'Groceries',
    'Transportation',
    'Entertainment',
    'Healthcare',
    'Insurance',
    'Education',
    'Dining',
    'Shopping',
    'Travel',
    'Fitness',
    'Beauty',
    'Home Improvement',
    'Pet Care',
    'Banking',
    'Taxes',
    'Investments',
    'Gifts',
    'Donations',
    'Office Supplies',
    'Technology',
    'Clothing',
    'Other'
  ];

  const [selectedCategory, setSelectedCategory] = useState('All');
  const [controlledSelected, setControlledSelected] = useState('All');

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto space-y-12">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-3xl font-bold text-gray-900 mb-4">
            Scrollable Category Tabs Component
          </h1>
          <p className="text-gray-600 max-w-2xl mx-auto">
            A horizontally scrollable category tabs component with auto-scroll behavior,
            keyboard navigation, touch support, and edge affordances.
          </p>
        </div>

        {/* Basic Usage */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Basic Usage</h2>
          <p className="text-gray-600 mb-4">
            Internal state management - component handles selection internally.
          </p>
          <ScrollableCategoryTabs
            categories={categories}
            onSelect={(category) => console.log('Selected:', category)}
          />
          <div className="mt-4 p-3 bg-gray-50 rounded text-sm text-gray-600">
            Selected: {selectedCategory}
          </div>
        </div>

        {/* Controlled Usage */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Controlled Usage</h2>
          <p className="text-gray-600 mb-4">
            External state management - parent component controls the selection.
          </p>
          <ScrollableCategoryTabs
            categories={categories}
            selected={controlledSelected}
            onSelect={setControlledSelected}
          />
          <div className="mt-4 space-y-3">
            <div className="p-3 bg-gray-50 rounded text-sm text-gray-600">
              Selected: {controlledSelected}
            </div>
            <div className="flex gap-2 flex-wrap">
              <button
                onClick={() => setControlledSelected('Utilities')}
                className="px-3 py-1 bg-orange-100 text-orange-700 rounded-full text-sm hover:bg-orange-200"
              >
                Set to Utilities
              </button>
              <button
                onClick={() => setControlledSelected('All')}
                className="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm hover:bg-gray-200"
              >
                Set to All
              </button>
              <button
                onClick={() => setControlledSelected('Shopping')}
                className="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm hover:bg-blue-200"
              >
                Set to Shopping
              </button>
            </div>
          </div>
        </div>

        {/* With Custom ARIA Label */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Custom ARIA Label</h2>
          <p className="text-gray-600 mb-4">
            Custom accessibility label for screen readers.
          </p>
          <ScrollableCategoryTabs
            categories={categories.slice(0, 10)}
            ariaLabel="Product category filters"
          />
        </div>

        {/* Features List */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Features</h2>
          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <h3 className="font-medium text-gray-900 mb-2">Scrolling Behavior</h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• Auto-scroll on tap of last visible tab</li>
                <li>• Smooth scrolling with scrollIntoView</li>
                <li>• Edge detection using getBoundingClientRect</li>
                <li>• Performance optimized with requestAnimationFrame</li>
              </ul>
            </div>
            <div>
              <h3 className="font-medium text-gray-900 mb-2">Accessibility</h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• role="tablist" and role="tab" attributes</li>
                <li>• Arrow key navigation</li>
                <li>• Home/End key support</li>
                <li>• ARIA-selected state management</li>
              </ul>
            </div>
            <div>
              <h3 className="font-medium text-gray-900 mb-2">Mobile Support</h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• Touch-friendly interactions</li>
                <li>• Drag detection to prevent false triggers</li>
                <li>• Responsive design with ResizeObserver</li>
                <li>• Smooth animations and transitions</li>
              </ul>
            </div>
            <div>
              <h3 className="font-medium text-gray-900 mb-2">Edge Indicators</h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• Gradient overlays at edges</li>
                <li>• Chevron buttons for navigation</li>
                <li>• Automatic visibility management</li>
                <li>• Hidden when no overflow</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Integration Notes */}
        <div className="bg-blue-50 rounded-lg border border-blue-200 p-6">
          <h2 className="text-xl font-semibold text-blue-900 mb-4">Integration Notes</h2>
          <div className="text-blue-800 space-y-3">
            <p>
              This component uses Tailwind CSS for styling. Make sure you have Tailwind configured in your project.
            </p>
            <p>
              The component supports both controlled and uncontrolled usage patterns.
              Use the <code className="bg-blue-100 px-1 rounded">selected</code> prop for controlled behavior.
            </p>
            <p>
              Keyboard shortcuts:
              <kbd className="bg-blue-100 px-2 py-1 rounded text-sm mx-1">←</kbd>
              <kbd className="bg-blue-100 px-2 py-1 rounded text-sm mx-1">→</kbd>
              Navigate tabs,
              <kbd className="bg-blue-100 px-2 py-1 rounded text-sm mx-1">Home</kbd>
              First tab,
              <kbd className="bg-blue-100 px-2 py-1 rounded text-sm mx-1">End</kbd>
              Last tab
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ScrollableCategoryTabsDemo;