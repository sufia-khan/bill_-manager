import React, { useState } from 'react';
import ScrollableCategoryTabs from './ScrollableCategoryTabs';

const ScrollableCategoryTabsDemo = () => {
  // Comprehensive categories for Bill Manager app with 70+ items
  const categories = [
    'All',
    'Utilities',
    'Electricity',
    'Water',
    'Gas',
    'Internet',
    'Phone',
    'Subscriptions',
    'Netflix',
    'Spotify',
    'YouTube Premium',
    'Disney+',
    'Amazon Prime',
    'Apple Music',
    'Rent',
    'Mortgage',
    'Apartment Rent',
    'House Rent',
    'Storage Rent',
    'Parking',
    'Groceries',
    'Supermarket',
    'Organic Food',
    'Meal Delivery',
    'Transportation',
    'Gas',
    'Public Transit',
    'Rideshare',
    'Car Payment',
    'Car Insurance',
    'Entertainment',
    'Movies',
    'Concerts',
    'Streaming Services',
    'Gaming',
    'Books',
    'Healthcare',
    'Doctor Visits',
    'Dental',
    'Vision',
    'Pharmacy',
    'Health Insurance',
    'Insurance',
    'Car Insurance',
    'Home Insurance',
    'Life Insurance',
    'Travel Insurance',
    'Education',
    'Tuition',
    'Online Courses',
    'Books & Materials',
    'Student Loans',
    'Dining',
    'Restaurants',
    'Fast Food',
    'Coffee Shops',
    'Food Delivery',
    'Shopping',
    'Clothing',
    'Electronics',
    'Home Goods',
    'Online Shopping',
    'Travel',
    'Flights',
    'Hotels',
    'Vacation Rentals',
    'Car Rental',
    'Fitness',
    'Gym Membership',
    'Yoga Classes',
    'Personal Trainer',
    'Sports Equipment',
    'Beauty',
    'Hair Salon',
    'Skincare',
    'Makeup',
    'Spa Services',
    'Home Improvement',
    'Furniture',
    'Appliances',
    'Home Repair',
    'Garden Supplies',
    'Pet Care',
    'Pet Food',
    'Veterinary',
    'Pet Insurance',
    'Pet Supplies',
    'Banking',
    'Bank Fees',
    'ATM Fees',
    'Wire Transfers',
    'Credit Card Fees',
    'Taxes',
    'Income Tax',
    'Property Tax',
    'Sales Tax',
    'Tax Preparation',
    'Investments',
    'Stocks',
    'Bonds',
    'Mutual Funds',
    'Retirement Savings',
    'Gifts',
    'Birthday Gifts',
    'Holiday Gifts',
    'Wedding Gifts',
    'Charitable Donations',
    'Donations',
    'Office Supplies',
    'Technology',
    'Software',
    'Apps',
    'Cloud Storage',
    'Web Hosting',
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
            Advanced Scrollable Category Tabs
          </h1>
          <p className="text-gray-600 max-w-2xl mx-auto">
            A highly optimized horizontally scrollable tabs component with intelligent auto-scroll,
            keyboard navigation, touch support, and responsive edge affordances.
          </p>
        </div>

        {/* Basic Usage - Uncontrolled Component */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Basic Usage (Uncontrolled)</h2>
          <p className="text-gray-600 mb-4">
            Component manages its own state. Internal state management.
          </p>
          <ScrollableCategoryTabs
            categories={categories}
            onSelect={(category) => console.log('Selected:', category)}
            ariaLabel="Product categories"
          />
          <div className="mt-4 p-3 bg-gray-50 rounded text-sm text-gray-600">
            <strong>Selected:</strong> {selectedCategory}
          </div>
        </div>

        {/* Controlled Usage */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Controlled Usage</h2>
          <p className="text-gray-600 mb-4">
            Parent component controls the selected state. External state management.
          </p>
          <ScrollableCategoryTabs
            categories={categories}
            selected={controlledSelected}
            onSelect={setControlledSelected}
            ariaLabel="Bill categories"
          />
          <div className="mt-4 space-y-3">
            <div className="p-3 bg-gray-50 rounded text-sm text-gray-600">
              <strong>Selected:</strong> {controlledSelected}
            </div>
            <div className="flex gap-2 flex-wrap">
              <button
                onClick={() => setControlledSelected('Utilities')}
                className="px-3 py-1 bg-orange-100 text-orange-700 rounded-full text-sm hover:bg-orange-200 transition-colors"
              >
                Set to Utilities
              </button>
              <button
                onClick={() => setControlledSelected('All')}
                className="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm hover:bg-gray-200 transition-colors"
              >
                Set to All
              </button>
              <button
                onClick={() => setControlledSelected('Shopping')}
                className="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm hover:bg-blue-200 transition-colors"
              >
                Set to Shopping
              </button>
              <button
                onClick={() => setControlledSelected('Investments')}
                className="px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm hover:bg-green-200 transition-colors"
              >
                Set to Investments
              </button>
            </div>
          </div>
        </div>

        {/* Responsive Testing */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Responsive Testing</h2>
          <p className="text-gray-600 mb-4">
            Resize your browser window to test responsive behavior with chevrons and gradients.
          </p>
          <div className="border border-gray-200 rounded-lg p-4">
            <ScrollableCategoryTabs
              categories={categories.slice(0, 8)} // Fewer categories for responsive testing
              ariaLabel="Responsive categories"
            />
          </div>
        </div>

        {/* Features Showcase */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Implemented Features</h2>
          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <h3 className="font-medium text-gray-900 mb-2 flex items-center">
                <span className="w-2 h-2 bg-orange-500 rounded-full mr-2"></span>
                Smart Auto-Scroll
              </h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• Tap last visible tab → scrolls next tabs into view</li>
                <li>• Center tabs when selected for optimal visibility</li>
                <li>• Uses getBoundingClientRect() for precise detection</li>
                <li>• Accounts for container padding and scroll position</li>
              </ul>
            </div>
            <div>
              <h3 className="font-medium text-gray-900 mb-2 flex items-center">
                <span className="w-2 h-2 bg-orange-500 rounded-full mr-2"></span>
                Keyboard Navigation
              </h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• Arrow keys (←→) navigate between tabs</li>
                <li>• Home/End keys jump to first/last tab</li>
                <li>• Proper focus management with auto-scroll</li>
                <li>• Full ARIA compliance with tablist roles</li>
              </ul>
            </div>
            <div>
              <h3 className="font-medium text-gray-900 mb-2 flex items-center">
                <span className="w-2 h-2 bg-orange-500 rounded-full mr-2"></span>
                Mobile Optimization
              </h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• Touch drag detection prevents false triggers</li>
                <li>• Smooth momentum scrolling on iOS devices</li>
                <li>• Touch-friendly button sizes and spacing</li>
                <li>• Debounced resize events for performance</li>
              </ul>
            </div>
            <div>
              <h3 className="font-medium text-gray-900 mb-2 flex items-center">
                <span className="w-2 h-2 bg-orange-500 rounded-full mr-2"></span>
                Edge Indicators
              </h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• Gradient overlays appear/disappear smoothly</li>
                <li>• Chevron buttons for manual navigation</li>
                <li>• Automatic visibility based on overflow</li>
                <li>• Hidden when no content overflow exists</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Integration Guide */}
        <div className="bg-orange-50 rounded-lg border border-orange-200 p-6">
          <h2 className="text-xl font-semibold text-orange-900 mb-4">Integration Guide</h2>
          <div className="space-y-4 text-orange-800">
            <div>
              <h3 className="font-medium mb-2">Installation</h3>
              <div className="bg-orange-100 rounded p-3 text-sm font-mono">
                npm install tailwindcss
              </div>
            </div>
            <div>
              <h3 className="font-medium mb-2">Basic Import</h3>
              <div className="bg-orange-100 rounded p-3 text-sm font-mono">
                import ScrollableCategoryTabs from './ScrollableCategoryTabs';
              </div>
            </div>
            <div>
              <h3 className="font-medium mb-2">Keyboard Shortcuts</h3>
              <div className="space-y-1">
                <div className="flex items-center gap-2 text-sm">
                  <kbd className="bg-orange-100 px-2 py-1 rounded">←</kbd>
                  <kbd className="bg-orange-100 px-2 py-1 rounded">→</kbd>
                  <span>Navigate tabs</span>
                </div>
                <div className="flex items-center gap-2 text-sm">
                  <kbd className="bg-orange-100 px-2 py-1 rounded">Home</kbd>
                  <span>First tab</span>
                </div>
                <div className="flex items-center gap-2 text-sm">
                  <kbd className="bg-orange-100 px-2 py-1 rounded">End</kbd>
                  <span>Last tab</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Performance Notes */}
        <div className="bg-gray-900 text-white rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">Performance Optimizations</h2>
          <div className="grid md:grid-cols-2 gap-6 text-gray-300 text-sm">
            <div>
              <h3 className="font-medium text-white mb-2">Rendering</h3>
              <ul className="space-y-1">
                <li>• Uses ResizeObserver for efficient size detection</li>
                <li>• Debounced resize events with requestAnimationFrame</li>
                <li>• Passive scroll event listeners</li>
                <li>• Efficient ref management with cleanup</li>
              </ul>
            </div>
            <div>
              <h3 className="font-medium text-white mb-2">Memory</h3>
              <ul className="space-y-1">
                <li>• Cleanup observers and event listeners</li>
                <li>• Cache container rect for better performance</li>
                <li>• Minimal state updates</li>
                <li>• Efficient tab visibility detection</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ScrollableCategoryTabsDemo;