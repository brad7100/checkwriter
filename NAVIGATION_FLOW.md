# CheckPrint Navigation Flow

## Visual Flow Diagram

```
┌─────────────────────┐
│   LOGIN PAGE        │
│                     │
│  📧 Email/Username  │
│  🔒 Password        │
│  [    Login    ]    │
│                     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  COMPANY PICKER     │
│                     │
│  ┌────┐  ┌────┐    │
│  │ 🏢 │  │ 🏢 │    │  Cards with logos/initials
│  │ Co1│  │ Co2│    │
│  └────┘  └────┘    │
│                     │
│  ┌────┐  ┌────┐    │
│  │ 🏢 │  │ ➕ │    │
│  │ Co3│  │Add │    │
│  └────┘  └────┘    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  ACCOUNT PICKER     │
│                     │
│  📍 Company: The Heritage LLC
│  [← Change Company] │
│                     │
│  ┌──────────────┐   │
│  │ 🏦 Operating │   │  Bank account cards
│  │ •••• 1234    │   │  showing last 4 digits
│  └──────────────┘   │
│                     │
│  ┌──────────────┐   │
│  │ 🏦 Payroll   │   │
│  │ •••• 5678    │   │
│  └──────────────┘   │
│                     │
│  ┌──────────────┐   │
│  │    ➕ Add    │   │
│  └──────────────┘   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│        MAIN APPLICATION              │
│                                      │
│  ┌──────────────────────────────┐   │
│  │ 🏢 The Heritage LLC          │   │  Company header
│  │    Operating - •••• 1234     │   │  with logo
│  │  [Change Co] [Change Acct]   │   │
│  └──────────────────────────────┘   │
│                                      │
│  [Check Writer] [History] [...]     │
│                                      │
│  ┌────────────────────────────┐     │
│  │ Check #: 1001              │     │
│  │ Date: 10/30/2024           │     │  Check writer
│  │ Pay to: Vendor Name        │     │  (scoped to
│  │ Amount: $1,000.00          │     │   selected
│  │ ...                        │     │   account)
│  └────────────────────────────┘     │
└─────────────────────────────────────┘
```

## Key Features

### 1. Company Picker
- **Large visual cards** with company logos
- Fallback to **styled initials** for companies without logos
- **Add Company** button for admins
- **Empty state** guidance for users without access

### 2. Account Picker
- Shows **only accounts for selected company**
- Displays **last 4 digits only** (security)
- **Bank name and account name** clearly visible
- **Back button** to change company

### 3. Main App Header
- **Company logo** prominently displayed
- **Company name and account info** visible
- **Change Company** and **Change Account** buttons always accessible
- **Gradient background** for visual appeal

### 4. Scoped Operations
- **Check Writer**: Creates checks only for selected account
- **History**: Shows checks only for selected company/account
- **No mixing** between different businesses
- Explicit **switch required** to work with different company

## User Experience Flow

1. **Login** → User authenticates
2. **Select Company** → User clicks company card
3. **Select Account** → User clicks bank account card
4. **Work** → Write checks, view history for that account
5. **Switch** → Click "Change Company" or "Change Account" to work with different entity

## Session Persistence

- Last selected company/account saved to user profile
- Returning users skip pickers if last selection valid
- Works across devices (saved in database)
- Also cached in localStorage for quick access
