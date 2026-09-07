# bytEM User Guide

<sub>Alpha · September 2026 · bytEM / OUDEA</sub>

**Publish, discover and exchange structured data through federated Data Rooms.**

> [!NOTE]
> bytEM is under active development. Interfaces, commands, and screens may change between releases.

## Workflow

```text
SUPPLY                                               DEMAND

Create Supply Room
        │
        ▼
Set DEID + Class
        │
        ▼
Add Data / References
        │
        ▼
Update Supply
        │
        ▼
Publish + Index ───────────────► Discover in Index
                                          │
                                          ▼
                                     Find(Optional)
                                (Review Reference DEID)
                                          │
                                          ▼
                                       Exchange
                               (Find runs automatically)
                                          │
                                          ▼
                                      Demand Room
                                          │
                                          ▼
                                 View Exchanged Data
```

### Quick Start

**Publish**

`Create Supply Room` → `Set DEID` → `Set Class` → `Load Supply` → `Update Supply`

**Access**

`Data Index` → `Access data` → `Single-Click Exchange` → `Demand Room`

## Contents

- [Getting Started](#getting-started)
- [Supplying Data](#supplying-data)
- [Accessing and Exchanging Data](#accessing-and-exchanging-data)
- [Reference](#reference)

## Getting Started
1. [What Is bytEM?](#1-what-is-bytem)
2. [Core Concepts](#2-core-concepts)
3. [Logging In](#3-logging-in)
4. [Overview Page](#4-overview-page)

#### Supplying Data
5. [Choose What You Want to Supply](#5-choose-what-you-want-to-supply)
6. [Create a Supply Room](#6-create-a-supply-room)
7. [Set the DEID and Class](#7-set-the-deid-and-class)
8. [Upload Data and Make It Exchangeable](#8-upload-data-and-make-it-exchangeable)
9. [Add Reference Data](#9-add-reference-data)

#### Accessing and Exchanging Data
10. [Create a Demand Room](#10-create-a-demand-room)
11. [Request Data Using Single-Click Exchange](#11-request-data-using-single-click-exchange)
12. [Find and Exchange Reference Data](#12-find-and-exchange-reference-data)
13. [View Your Exchanged Data](#13-view-your-exchanged-data)

#### Reference
14. [Terminal Commands Reference](#14-terminal-commands-reference)
15. [Status Indicators](#15-status-indicators)
16. [FAQ](#16-faq)
17. [Troubleshooting](#17-troubleshooting)
18. [Getting Help](#18-getting-help)


## Getting Started

### 1. What Is bytEM?

bytEM is a platform for **sharing and exchanging data**.

There are two main parts of the process:

| Process | Purpose |
| --- | --- |
| **Supply** | Publish data that you want to make available |
| **Demand** | Request and access data |

For example:

1. A city publishes water quality data in a Supply Room.
2. A user requests the data.
3. bytEM creates or uses a Demand Room to provide access to the requested data.

bytEM also supports **Reference data**, which allows you to include the DEID of another data entity and exchange it later from a Demand Room.


### 2. Core Concepts

Before you start, it is useful to understand the following concepts.

| Concept | Meaning |
| --- | --- |
| **Supply Room** | A room in which data is added and published |
| **Demand Room** | A room used to access requested and exchanged data |
| **DEID** | A unique Data Entity ID, usually expressed as a URL |
| **Class** | A category describing what type of data is stored in a Supply Room |
| **Reference** | A DEID pointing to another data entity that can later be found and exchanged |
| **Find** | Retrieves information about a DEID before exchange |
| **Exchange** | Brings data for a DEID into a Demand Room |

#### Supply Room

A **Supply Room** is where you add and publish data.

For example:

- Water quality data
- A dataset
- API data
- HTML content
- Reference data

Supply Rooms are shown with a 🟢 **green tag**.

#### Demand Room

A **Demand Room** is used when data is requested.

It contains the requested and exchanged data.

Demand Rooms are shown with a 🟣 **purple tag**.

#### DEID

A **DEID (Data Entity ID)** is a unique identifier for a data entity.

A DEID is usually a URL.

For example:

```text
https://cities.app/de/bb/ahrensfelde
```

The DEID helps identify and find the data in bytEM.

#### Class

A **Class** is a category that describes what type of data is stored in a Supply Room.

For example:

```text
ahrensfelde
```

The Class helps categorize and identify your data.

#### Reference Data

A **Reference** contains the DEID of another data entity.

You can add Reference data to a Supply Room using:

```bash
load-supply reference
```

After the data is requested, the Reference DEID can be viewed in the **Reference** tab inside the Demand Room.

From there, you can:

1. Find the Reference DEID.
2. Review the available data.
3. Exchange the data if you have the required permissions.

> [!IMPORTANT]
> The user must have a **power level 51 or higher** to perform an exchange.

#### Supply and Demand

#### Supply

Supply is created manually. You:

1. Create a Supply Room.
2. Set the DEID and Class.
3. Add your data.
4. Update the supply.

#### Demand

Demand happens when a user requests data.

bytEM creates or uses a Demand Room where the requested and exchanged data can be accessed.

> [!TIP]
> **Simple idea:** First, publish your data in a Supply Room. Then, request and access data through a Demand Room.

> [!NOTE]
> You can also create a Demand Room manually. However, in the current version of bytEM, manually created Demand Rooms do not support exchanging data.


### 3. Logging In

**Login URL:** `https://bytem.your.domain/login`

#### Sign In

1. Open the login page in your browser.
2. Leave the **Homeserver** value unchanged unless your administrator gives you a different value.
3. Enter your **Username**.
4. Enter your **Password**.
5. Use the eye icon 👁 to show or hide your password.
6. Optionally select **Remember me**.
7. Click **Sign In**.

<img width="760" alt="Login page" src="https://github.com/user-attachments/assets/f7404784-2acb-4486-bec4-1e11ab0c4ad7" />

After sign-in, bytEM opens **Overview**.

#### Create a New Matrix Account

If you do not have a Matrix account, click **Create one** below the login form.

**Sign Up URL:** `https://bytem.your.domain/signup`

A registration form will open.

1. Enter a **Username**.
2. Enter a **Password**.
3. Confirm your password.
4. Click **Create Account**.

<img width="760" alt="Create Matrix account" src="https://github.com/user-attachments/assets/dfa90c60-480f-4f31-a197-fc3bd3068327" />

After creating your account, log in using your new Matrix username and password.


### 4. Overview Page

After logging in, you will see the **Overview** page.

<img width="760" alt="Overview page" src="https://github.com/user-attachments/assets/7ae05683-c659-474e-8e9b-65540d5cf21b" />

The Overview page contains:

- The **Terminal**
- The **Data Rooms List**
- Room management options

#### Data Rooms List

The **Data Rooms List** shows rooms available to you.

| Tag | Meaning |
| --- | --- |
| 🟢 Green | Supply Room |
| 🟣 Purple | Demand Room |
| ⚪ Grey | You have not joined the room yet |

If you have not joined a room, click the room to see the available options. From there, you can join the room if you want to.

> [!NOTE]
> Only administrators can join rooms.

Click a room to open its context menu.

| Option | Description |
| --- | --- |
| **Open Data Room** | Opens the room |
| **Edit Data Room Name** | Changes the room name |
| **Copy Room ID** | Copies the Matrix Room ID |
| **Leave Data Room** | Removes you from the room |
| **Delete Data Room** | Permanently deletes the room and its data |

> [!NOTE]
> Room management options such as **Edit**, **Leave**, **Delete**, and **Join** are available only to administrators.

#### Buttons

| Button | Action |
| --- | --- |
| **Create ▾** | Opens the Create Data Room dialog |
| **Clear Terminal** | Clears the Terminal output |

> [!NOTE]
> The **Create** button is available only to administrators.


## Supplying Data

### 5. Choose What You Want to Supply

Before creating a Supply Room, decide what type of data you want to add.

bytEM supports different supply types.

| Type | Use when... |
| --- | --- |
| **Dataset** | You have a file to upload |
| **API** | Your data is available through an API |
| **HTML** | You want to provide HTML or web content |
| **Reference** | You want to add the DEID of another data entity |

#### Example

A city can provide its water quality readings as a **Dataset**.

If you want to include another data entity using its DEID, you can use the **Reference** supply type.


### 6. Create a Supply Room

Create a Supply Room to publish a data entity.

#### How to Create a Supply Room

1. Go to the **Overview** page.
2. Click **Create ▾**.
3. Select **Create Data Room**.
4. Set **Room Base Type** to `supply`.
5. Enter the room details.

| Field | Description |
| --- | --- |
| **Room Base Type** | Select `supply` |
| **Data Room Name** | Enter a clear name for your room |
| **Room Description** | Describe the data |
| **Data Room Alias** | Use the suggested alias if appropriate |
| **Room Type** | Select the appropriate room type |
| **DEID URL** | Enter the identity for your data |

6. Click **Create**.

The new room appears in the Data Rooms List with a 🟢 green tag.

<img width="760" alt="Create Supply Room" src="https://github.com/user-attachments/assets/45e8f6e6-432a-4c06-96aa-6be509e2456d" />

#### Example

You can create a Supply Room called:

**Frankfurt Water Quality**

This room can contain water quality data for Frankfurt.


### 7. Set the DEID and Class

After creating a Supply Room, set its **DEID** and **Class**.

Open the Supply Room and select **Open Data Room**.

#### Set the DEID

You can view and set the DEID in different ways.

#### Option 1 — Use the Terminal

Run:

```bash
room-deid --schema
```

This displays the DEID template.

#### Option 2 — Use the DEID Button

Click the **room-deid** button above the Terminal.

This also displays the DEID template.

> [!NOTE]
> Options 1 and 2 are used to view the DEID template.

<img width="760" alt="DEID template" src="https://github.com/user-attachments/assets/bac9679d-9b77-41c3-bbf7-07e875ff2924" />

#### Option 3 — Use the Command Tab

1. Open the **Command** tab.
2. Enter the DEID value.
3. Click **Save**.

<img width="760" alt="Set DEID from Command tab" src="https://github.com/user-attachments/assets/d0f09d9a-5b50-4378-8f2c-afd6a6bfd6fb" />

> [!NOTE]
> The DEID must contain the full domain URL, for example: `https://bytem.your.domain/de/bb/ahrensfelde`. Make sure to use the correct domain for your instance.


#### DEID Example

A DEID is usually a URL that identifies your data.

For example:

```text
https://cities.app/de/bb/ahrensfelde
```

Choose a meaningful URL that clearly describes your data.


> [!IMPORTANT]
> Once data has been uploaded to a Supply Room, its DEID cannot be changed. Make sure you set the correct DEID before uploading data.

#### Set the Class

You can set the Class in the same way.

#### Option 1 — Use the Terminal

Run:

```bash
room-class --schema
```

This displays the Class template.

#### Option 2 — Use the Class Button

Click the **room-class** button above the Terminal.

This also displays the Class template.

> [!NOTE]
> Options 1 and 2 are used to view the Class template.

<img width="760" alt="Class template" src="https://github.com/user-attachments/assets/663c513c-1b22-4e8d-9217-59b1b86d4ea1" />

#### Option 3 — Use the Command Tab

1. Open the **Command** tab.
2. Enter the Class details.
3. Click **Save**.

<img width="760" alt="Set Class from Command tab" src="https://github.com/user-attachments/assets/143ec434-9479-4030-9fea-c41a0a668dea" />

#### Class Example

```text
ahrensfelde
```


### 8. Upload Data and Make It Exchangeable

After setting the DEID and Class, add the supply data.

#### Option 1 — Use the Terminal

For a dataset, run:

```bash
load-supply dataset
```

This allows you to load your dataset.

#### Use the Files Tab

1. Open the **Files** tab.
2. Select **via File System**.
3. Choose your file.

If available, you can use **Download from bytEM** to download data.

<img width="760" alt="Files tab" src="https://github.com/user-attachments/assets/f728aa01-5938-4f42-a486-57af3f70277a" />

#### Option 2 — Load a Template

In the **Data Exchange / Provision** section:

1. Select the type of data you want to add.
2. Enter your data.
3. Click **Load Template**.

<img width="760" alt="Load template" src="https://github.com/user-attachments/assets/f6ae5763-f98e-4634-afb0-ee0f37715c4c" />

#### Update the Supply

After adding your data:

1. Click **Update Supply**.
2. Check the **DEID Information** panel.

The following indicators should become ready:

- **Supply**
- **Register**
- **Exchangeable**

<img width="760" alt="Entity readiness" src="https://github.com/user-attachments/assets/ae39c95b-87db-4469-8c5f-72a327b4091c" />

Once your data is exchangeable and indexed, it can be requested by users on index page.


### 9. Add Reference Data

Add a **Reference DEID** when the supply links to another data entity.

A Reference DEID identifies another data entity that can later be found and exchanged.

#### How to Add a Reference

1. Open your Supply Room.
2. Load the **Reference** supply type.

Run:

```bash
load-supply reference
```

3. Add the **Reference DEID**.
4. Save the Reference information.
5. Click **Update Supply** to publish your changes.

The Reference DEID is now included in your supplied data.

<img width="760" alt="Add Reference data" src="https://github.com/user-attachments/assets/7441b431-79e6-4d91-aa22-f4f2596aa6d9" />

> [!NOTE]
> The Reference DEID can be accessed later from the **Reference** tab inside the Demand Room.

#### Example

A Reference can contain a DEID such as:

```text
https://cities.app/de/he/babenhausen
```

This DEID identifies data that can be found and exchanged later.

## Accessing and Exchanging Data

### 10. Create a Demand Room

#### How to Create a Demand Room

1. Go to the **Overview** page.
2. Click **Create ▾**.
3. Select **Create Data Room**.
4. Set **Room Base Type** to `demand`.
5. Enter the room details.

| Field | Description |
| --- | --- |
| **Room Base Type** | Select `demand` |
| **Data Room Name** | Enter a clear name for your room |
| **Room Description** | Describe the purpose of the room |
| **Data Room Alias** | Use the suggested alias if appropriate |

6. Click **Create**.

<img width="760" alt="Create Demand Room" src="https://github.com/user-attachments/assets/13b3d060-7e62-4e04-ad07-0d5973932fc3" />

After creating the Demand Room, open it from the **Data Rooms List**.

<img width="760" alt="Demand Room" src="https://github.com/user-attachments/assets/23dee18d-2e91-48eb-aaeb-779b978bc9cf" />

<img width="760" alt="Demand Room details" src="https://github.com/user-attachments/assets/2df21bc0-ba9a-49a7-a8cf-156bdce02e4c" />

> [!IMPORTANT]
> In the current version, data cannot be exchanged from a Demand Room that is created manually. To exchange data, use the **Single-Click Exchange** flow described below.


### 11. Request Data Using Single-Click Exchange

> [!TIP]
> **Recommended:** Use the **Data Index** to find and request publicly available data.

#### Step 1 — Open the Data Index

Open:

`https://bytem.your.domain/index-room`

The **Data Index** lists publicly indexed data entities.

<img width="760" alt="Data Index" src="https://github.com/user-attachments/assets/ad6c1b46-7980-4e12-87f0-1d7b5a5135d2" />

You can browse, search, sort, and filter the available data.

#### Search for Data

Use the search bar to search by:

- DEID
- Name
- Class

#### Filter and Sort Data

Depending on the available options, you can filter or sort data by:

- Entity
- Dataset
- City
- Category
- Region

#### Understand the Data Cards

Each data card may display information such as:

- Data name
- Exchange status
- DEID
- Data category
- Domain
- Source information

When you find the data you need, click **Access data →**.

#### Step 2 — Select the Data You Want

Click **Access data →**.

The Data Access page will open.

Here, you can review information about the selected data.

#### Step 3 — Enter Your Details

Enter the required information.

| Field | Required? | Description |
| --- | --- | --- |
| **Matrix Username** | Yes | Your Matrix account username |
| **Email** | No | Optional |

Depending on the requested data, a location may also be required.

<img width="760" alt="Data Access page" src="https://github.com/user-attachments/assets/82c791ef-b1b4-475b-b526-a7212352cfd2" />

After entering the required information, click **Single-Click Exchange**.

#### Step 4 — Wait for the Exchange Process

bytEM will process your request.

The progress page shows the current status.

During this process, bytEM may:

- Create a Demand Room
- Configure the requested data
- Resolve the required supply data
- Exchange the requested data
- Process the results
- Configure Demand Room permissions
- Give your Matrix account access to the Demand Room

<img width="760" alt="Exchange progress" src="https://github.com/user-attachments/assets/6d212f48-cf76-44c4-b0af-595329c8bb27" />

Wait until the process is completed successfully.

#### Existing Demand Room

If a Demand Room already exists for the requested data, bytEM may use the existing room instead of creating a new one.

#### Step 5 — Open the Demand Room

After the exchange is complete, you will see a confirmation that your Demand Room is ready.

Click **Open Demand Room**.

<img width="760" alt="Demand Room ready" src="https://github.com/user-attachments/assets/232dd90f-3fa1-433b-8fbe-7428eeb5979d" />

#### Step 6 — Log In

If you are not already logged in, you will be redirected to the login page.

Enter your:

- Matrix Username
- Password

<img width="760" alt="Login page" src="https://github.com/user-attachments/assets/adbf50b7-2424-4530-a870-423d3ed85d04" />

After successfully logging in, you will be redirected to the Demand Room.

> [!NOTE]
> If you are already logged in, you may be taken directly to the Demand Room.

If you do not have a Matrix account, click **Create one** on the login page.


### 12. Find and Exchange Reference Data

If the requested data contains the **Reference** supply type, use the Demand Room to find and exchange its **Reference DEIDs**.

#### Step 1 — Open the Demand Room

Open your 🟣 **Demand Room**.

Click **Open Data Room**.

<img width="760" alt="Open Demand Room" src="https://github.com/user-attachments/assets/b4b6a722-50a6-48b6-9d3d-4dcb32f21e76" />

#### Step 2 — Open the Reference Tab

Inside the Demand Room, open the **Reference** tab.

The Reference tab displays the Reference DEIDs included in the requested data.

<img width="760" alt="Reference tab" src="https://github.com/user-attachments/assets/4e81f0e1-4802-4fd3-bda0-6c50d21c1a96" />


#### Step 3 — Find the Reference DEID (Optional)

You can use **Find** to review information about a Reference DEID before exchanging it.

You can select the Reference DEID and use **Find**.

Or use the Terminal command:

```bash
find <deid_url>
```

For example:

```bash
find https://cities.app/de/he/babenhausen
```

The **Find** action shows information about the referenced data.

> [!NOTE]
> Running **Exchange** automatically performs the  Find process. You can use **Find** separately when you want to review the Reference DEID before exchanging it.


#### Step 4 — Exchange the Reference DEID

To exchange the Reference DEID,

Use:

```bash
exchange-data <deid_url>
```

For example:

```bash
exchange-data https://cities.app/de/he/babenhausen
```

When you run the exchange, bytEM automatically performs the Find process and then exchanges the data into the Demand Room.

<img width="760" alt="Exchange Reference data" src="https://github.com/user-attachments/assets/19cde1bb-ed2e-4149-9dbc-d61ec42d9848" />

#### Permission Requirement

> [!IMPORTANT]
> The exchange action requires the appropriate user permissions.

The user must have a **power level 51 or higher** to perform the exchange.


### 13. View Your Exchanged Data

After the exchange is complete, open the **Exchanged** tab in your Demand Room.

<img width="760" alt="Exchanged data" src="https://github.com/user-attachments/assets/285cf2f1-093a-4a31-8239-4e52882e1342" />

The exchanged data may be displayed in different tabs depending on the type of data returned.

| Tab | Description |
| --- | --- |
| **MetaData** | Shows information about the exchanged data |
| **Reference** | Shows reference-related data |
| **Map** | Shows geographic or location data |
| **HTML** | Shows HTML or web content |
| **API** | Shows API-related data |
| **bytEM Repo** | Shows available files or assets |
| **Echart** | Shows a computed result as a chart |

> [!NOTE]
> Not every Demand Room displays all of these tabs. The available tabs depend on the type of data returned during the exchange.

> [!NOTE]
> Some tabs may require additional user permissions.


## Reference

### 14. Terminal Commands Reference

The Terminal is available from:

- The Overview page
- Supply Rooms
- Demand Rooms

Type:

```bash
help
```

to see the commands available in your current location.

<img width="760" alt="Terminal help commands" src="https://github.com/user-attachments/assets/625b6687-ca8a-4047-addc-992199678e51" />

> [!NOTE]
> The commands shown by `help` may depend on where you are in bytEM.

#### Common Commands

#### Help

```bash
help
```

Shows the available commands.

#### Clear

```bash
clear
```

Clears the Terminal output.

#### Delete a Room

```bash
delete-room --room-id <room_id>
```

Deletes a room.

> [!WARNING]
> Deleting a room may permanently remove the room and its data.

> [!NOTE]
> Only admin can delete a room.

#### Supply Room Commands

#### View the DEID Template

```bash
room-deid --schema
```

Displays the DEID template.

#### View the Class Template

```bash
room-class --schema
```

Displays the Class template.

#### Load Supply Data

```bash
load-supply <supply-type>
```

Loads a supply type.

Examples include:

```text
dataset
api
html
reference
```

#### Show Room Index Information

```bash
show-room-index
```

Shows the room's index information.

#### Set or View Room Location

```bash
room-location --schema
```

Shows the location template.

#### Demand Room Commands

#### Find a DEID

```bash
find <deid_url>
```

Finds information for a specific DEID.

> [!TIP]
> **Optional:** Use **Find** when you want to review information about a Reference DEID before exchanging it.

#### Exchange Data

```bash
exchange-data <deid_url>
```

Exchanges the data for the specified DEID.

> [!IMPORTANT]
> **Permission requirement:** The user must have a **power level 51 or higher** to perform an exchange.


### 15. Status Indicators

The **Entity Readiness** panel shows whether the data is ready.

Common statuses include:

| Status | Meaning |
| --- | --- |
| **Supply** | The supply data is available |
| **Register** | The data has been registered |
| **Exchangeable** | The data is ready to be exchanged |

When the required indicators are ready, your data can be indexed and requested.

<img width="760" alt="Status indicators" src="https://github.com/user-attachments/assets/8f8d5730-bb0b-4755-9e22-e8330edd2bbe" />


### 16. FAQ

#### Do I need to write code to use bytEM?

No. Most actions can be performed using the bytEM interface.

The Terminal is also available for users who prefer using commands.

#### What is the difference between a Supply Room and a Demand Room?

A **Supply Room** is used to publish data.

A **Demand Room** is used to access requested and exchanged data.

#### What is a Reference DEID?

A Reference DEID identifies another data entity.

It is added using the **Reference** supply type and can later be found and exchanged from a Demand Room.

#### Do I need to perform Find before Exchange?

No. **Find is optional.**

You can use **Find** to review information about a Reference DEID before exchanging it.

When you run **Exchange**, bytEM automatically performs the Find process.


#### Can every user exchange data?

No.

The user must have the required permissions.

According to the current requirement, the user must have a **power level above 51** to perform an exchange.

#### Can I change my DEID after uploading data?

No.

Once data has been uploaded to a Supply Room, the DEID may be locked.

Make sure you set the correct DEID before uploading your data.


### 17. Troubleshooting

#### I Cannot Log In

Check:

- Your username
- Your password
- Your Homeserver

If the problem continues, contact your administrator.

#### I Cannot Perform an Exchange

Check your user permissions.

The exchange action requires a user power level above **51**.

If your power level is not high enough, contact the room administrator.

#### I Cannot Find the Reference Data

Check that:

- The Reference DEID is correct.
- You performed the **Find** action correctly.
- The referenced data is available and accessible.

#### My Data Does Not Appear

Try the following:

1. Wait a few moments.
2. Refresh the page.
3. Check the Supply status.
4. Confirm that **Update Supply** was completed.

#### My DEID Is Locked

This can happen after data has been uploaded.

If you need a different DEID, you may need to create a new Supply Room.

### 18. Getting Help

#### Use the Terminal

Type:

```bash
help
```

to see the commands available in your current location.

#### Contact Support

If you need additional help, contact your bytEM administrator or join the bytEM administrator support room.

* **Support Room:** `#bytem-install-admin:matrix.liberbyte.com`
* **Direct link:** [#bytem-install-admin:matrix.liberbyte.com](https://matrix.to/#/#bytem-install-admin:matrix.liberbyte.com)

*bytEM User Guide — © 2026*

