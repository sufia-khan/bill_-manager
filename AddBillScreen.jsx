import React, { useState } from 'react';

// Default categories with emojis for the Bill Manager app
const DEFAULT_CATEGORIES = [
  "Rent", "Utilities", "Electricity", "Water", "Gas", "Internet", "Phone",
  "Subscriptions", "Streaming", "Groceries", "Transport", "Fuel", "Insurance",
  "Health", "Medical", "Education", "Entertainment", "Credit Card", "Loan",
  "Taxes", "Savings", "Donations", "Home Maintenance", "HOA", "Gym",
  "Childcare", "Pets", "Travel", "Parking", "Other"
];

// CategoryIcon component with emoji mapping
function CategoryIcon({ category }) {
  const emojiMap = {
    Rent: "🏠️",
    Utilities: "💡",
    Electricity: "⚡",
    Water: "💧",
    Gas: "🔥",
    Internet: "🌐",
    Phone: "📱",
    Subscriptions: "📋",
    Streaming: "📺",
    Groceries: "🛒",
    Transport: "🚌",
    Fuel: "⛽",
    Insurance: "🛡️",
    Health: "💊",
    Medical: "🏥",
    Education: "📚",
    Entertainment: "🎬",
    "Credit Card": "💳",
    Loan: "💰",
    Taxes: "📝",
    Savings: "🏦",
    Donations: "❤️",
    "Home Maintenance": "🔧",
    HOA: "🏘️",
    Gym: "💪",
    Childcare: "👶",
    Pets: "🐾",
    Travel: "✈️",
    Parking: "🅿️",
    Other: "📁"
  };

  return <span className="text-lg mr-2">{emojiMap[category] || "📁"}</span>;
}

export default function AddBillScreen() {
  // Form state
  const [title, setTitle] = useState("");
  const [amount, setAmount] = useState("");
  const [due, setDue] = useState("");
  const [selectedCategory, setSelectedCategory] = useState(DEFAULT_CATEGORIES[0]);
  const [repeat, setRepeat] = useState("None");
  const [notes, setNotes] = useState("");

  // UI state
  const [open, setOpen] = useState(false);
  const [errors, setErrors] = useState({});
  const [toast, setToast] = useState(null);

  // Form validation
  function validate() {
    const newErrors = {};

    if (!title.trim()) {
      newErrors.title = "Title is required";
    }

    if (!due) {
      newErrors.due = "Due date is required";
    }

    if (!amount || Number(amount) <= 0) {
      newErrors.amount = "Please enter a valid amount";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  // Form submission handler
  function handleSave(e) {
    e.preventDefault();

    if (!validate()) {
      return;
    }

    // Here you would typically save the bill to your backend/state
    console.log({
      title: title.trim(),
      amount: Number(amount),
      due,
      category: selectedCategory,
      repeat,
      notes: notes.trim()
    });

    // Show success toast
    setToast("Bill saved successfully!");

    // Reset form after successful save
    setTitle("");
    setAmount("");
    setDue("");
    setSelectedCategory(DEFAULT_CATEGORIES[0]);
    setRepeat("None");
    setNotes("");
    setErrors({});

    // Hide toast after 2 seconds
    setTimeout(() => setToast(null), 2000);
  }

  return (
    <div className="min-h-screen bg-white p-6 text-gray-800" style={{ fontFamily: 'Inter, system-ui, sans-serif' }}>
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <h2 className="text-2xl font-semibold text-[#FF8C00]">Add Bill</h2>
        <button
          className="text-gray-500 hover:text-gray-700 text-xl transition-colors"
          onClick={() => window.history.back()}
        >
          ✕
        </button>
      </div>

      {/* Main Form */}
      <form onSubmit={handleSave} className="space-y-6 max-w-md mx-auto">
        {/* Title Field */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Title <span className="text-red-500">*</span>
          </label>
          <input
            className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-[#FF8C00] focus:border-transparent transition-all ${
              errors.title ? 'border-red-400 bg-red-50' : 'border-gray-200 hover:border-gray-300'
            }`}
            placeholder="e.g. Electricity bill"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
          {errors.title && (
            <p className="text-xs text-red-600 mt-1">{errors.title}</p>
          )}
        </div>

        {/* Amount Field */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Amount <span className="text-red-500">*</span>
          </label>
          <input
            type="number"
            step="0.01"
            className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-[#FF8C00] focus:border-transparent transition-all ${
              errors.amount ? 'border-red-400 bg-red-50' : 'border-gray-200 hover:border-gray-300'
            }`}
            placeholder="0.00"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
          />
          {errors.amount && (
            <p className="text-xs text-red-600 mt-1">{errors.amount}</p>
          )}
        </div>

        {/* Due Date Field */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Due date <span className="text-red-500">*</span>
          </label>
          <input
            type="date"
            className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-[#FF8C00] focus:border-transparent transition-all ${
              errors.due ? 'border-red-400 bg-red-50' : 'border-gray-200 hover:border-gray-300'
            }`}
            value={due}
            onChange={(e) => setDue(e.target.value)}
          />
          {errors.due && (
            <p className="text-xs text-red-600 mt-1">{errors.due}</p>
          )}
        </div>

        {/* Category Dropdown */}
        <div className="relative">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Category
          </label>
          <button
            type="button"
            onClick={() => setOpen(!open)}
            className="w-full px-4 py-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-[#FF8C00] focus:border-transparent hover:border-gray-300 transition-all flex justify-between items-center"
          >
            <div className="flex items-center">
              <CategoryIcon category={selectedCategory} />
              <span>{selectedCategory}</span>
            </div>
            <svg
              className={`w-4 h-4 text-gray-400 transition-transform ${open ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          {/* Dropdown Menu */}
          {open && (
            <div className="absolute z-10 mt-1 w-full bg-white border border-gray-100 rounded-lg shadow-lg max-h-56 overflow-y-auto">
              {DEFAULT_CATEGORIES.map((category) => (
                <div
                  key={category}
                  onClick={() => {
                    setSelectedCategory(category);
                    setOpen(false);
                  }}
                  className="flex items-center px-4 py-3 hover:bg-orange-50 cursor-pointer transition-colors border-b border-gray-50 last:border-b-0"
                >
                  <CategoryIcon category={category} />
                  <span>{category}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Repeat Dropdown */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Repeat
          </label>
          <select
            value={repeat}
            onChange={(e) => setRepeat(e.target.value)}
            className="w-full px-4 py-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-[#FF8C00] focus:border-transparent hover:border-gray-300 transition-all"
          >
            <option value="None">None</option>
            <option value="Weekly">Weekly</option>
            <option value="Monthly">Monthly</option>
            <option value="Quarterly">Quarterly</option>
            <option value="Yearly">Yearly</option>
          </select>
        </div>

        {/* Notes Field */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Notes
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
            placeholder="Add any details about this bill..."
            className="w-full px-4 py-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-[#FF8C00] focus:border-transparent hover:border-gray-300 transition-all resize-none"
          />
        </div>

        {/* Submit Button */}
        <button
          type="submit"
          className="w-full bg-[#FF8C00] text-white py-3 rounded-lg font-medium shadow-sm hover:bg-[#e67c00] transition-colors focus:ring-2 focus:ring-[#FF8C00] focus:ring-offset-2"
        >
          Save Bill
        </button>
      </form>

      {/* Toast Notification */}
      {toast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 bg-gray-900 text-white px-6 py-3 rounded-lg shadow-lg transform transition-all duration-300 ease-out">
          <div className="flex items-center">
            <svg className="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4a1 1 0 00-1.414-1.414L11.414 10l1.293-1.293z" clipRule="evenodd" />
            </svg>
            {toast}
          </div>
        </div>
      )}
    </div>
  );
}