# Recommendation System Analysis and Modelling

## Introduction
Recommendation systems are essential for delivering personalised user experiences across various platforms, including e-commerce, streaming services, social media and news websites.
These systems leverage historical and user-specific data to generate recommendations, enhancing user satisfaction, engagement and conversion rates. From e-commerce platforms and streaming services to social media and news websites, recommendation systems are vital in shaping the user experience.

The ability to provide personalised recommendations has significant business value. Organisations can boost user retention, increase sales and improve customer satisfaction by understanding user preferences, behaviours and interactions. As recommendation systems evolve, they face the challenge of offering accurate, diverse and relevant suggestions while handling large volumes of data and maintaining real-time performance. 

This project aims to develop a recommendation system that leverages historical user data to provide tailored recommendations across different domains, such as product recommendations, content suggestions and service optimisation.

## CRISP DM Framework
The analysis followed the CRISP-DM methodology, which includes the following stages:

Business Understanding

a. Define the project objectives and business goals.

b. Identify key questions that need to be answered. 

Data Understanding 

a. Collect data from various sources.

b. Explore the data (e.g., summary statistics, missing values, patterns).

c. Identify potential issues like inconsistencies, duplicates and outliers

Data Preparation

a. Clean and preprocess the data.

b. Handle missing values and inconsistencies.

c. Transform data into the right format for analysis.

d. Feature selection and engineering.

Modelling

a. Apply statistical or machine learning models.

b. Train models using relevant algorithms.

c. Tune hyperparameters to improve performance.

Evaluation

a. Assess the model’s performance using metrics.

b. Compare models and select the best one.

c. Ensure the model meets business objectives.

Deployment

a. Implement the model in a real-world environment.

b. Monitor its performance and make improvements if needed.

### 1. Business Understanding

The objectives were defined below, followed by the formulation of analytic questions to guide the modelling process.

Key objectives of the project include:

a. Develop Personalised Recommendations: Tailor suggestions based on user behaviour and past interactions.

b. Address Diverse Use Cases: Implement systems for product, content and service recommendations.

c. Utilise Historical Data: Leverage past user actions to make accurate predictions.

d. Enhance User Engagement: Improve user satisfaction and retention through relevant suggestions.

e. Ensure Scalability & Real-Time Performance: Handle large data volumes and provide recommendations promptly.

f. Boost Business Metrics: Increase sales and conversion rates through better user personalisation.

g. Balance Accuracy & Diversity: Provide relevant but varied recommendations to avoid monotony.

Analytic Questions:

a. How effective is the user funnel?

b. What are the trends in user activity over time?

c. When are users most active?

d. How does the availability of items impact user interactions?

e. How do conversion rates vary across different times of the day?

f. What is the relationship between user session duration and purchase likelihood?

g.

### 2. Data Understanding:

The dataset consists of three files: events.csv, item_properties.csv and category_tree.csv, which collectively describe the interactions and properties of items on an e-commerce website. The data, collected over months, is raw and contains hashed values due to confidentiality concerns. The goal of publishing this dataset is to support research in recommender systems using implicit feedback.

2.1 Behaviour Data (events.csv)

The behaviour data includes a total of 2,756,101 events, with 2,664,312 views, 69,332 add-to-cart actions and 22,457 transactions, recorded from 1,407,580 unique visitors. Each event corresponds to one of three types of interactions: "view", "addtocart" or "transaction". These implicit feedback signals are crucial for recommender systems:

View: Represents a user showing interest in an item.

Add to Cart: Indicates a higher level of intent to purchase.

Transaction: Represents a completed purchase.

2.2 Item Properties (item_properties.csv)

This file contains 20,275,902 rows, representing various properties of 417,053 unique items. Each property may change over time (e.g., price updates), with each row capturing a snapshot of an item’s property at a specific timestamp. For items with constant properties, only a single snapshot is recorded. The file is split into two due to its size and it contains detailed item information, which is essential for building item profiles and understanding how item properties influence user behaviour.

2.3 Category Tree (category_tree.csv)

The category_tree.csv file outlines the hierarchical structure of item categories. It provides a category-based organisation of the products, which can help in grouping items into broader categories or subcategories. This file is important for building models that recommend items within specific categories or using category-based clustering for recommendations.

### 3. Data Preparation: 
#### a. Data Processing of Event file
• To ensure the dataset was ready for analysis, a meticulous data preparation process was carried out as follows:

• The events file was read using a read-in-chunk function. This function enables large files to be loaded in smaller manageable portions, thereby preventing memory overload and ensuring efficiency. The chunks were then bound into a single data frame.

• The dataset was inspected thoroughly to understand its structure and content. Columns were verified to match the document description and then standardised to "timestamp", "visitorid", "event", "itemid" and "transaction" to ensure consistency throughout the project.

• Raw timestamps provided in Unix format (milliseconds since the epoch) were converted into a human-readable date-time format (POSIXct) using the lubridate package. This conversion was essential for any subsequent time-based analysis.

• Duplicate rows were removed to eliminate any repeated events that might skew the analysis.

• The dataset was sorted chronologically by visitorid and timestamp. This ordering was crucial for computing time differences between consecutive events for each visitor. The shift function in data.table was used to calculate these differences in seconds. Naturally, the first event for each visitor resulted in an NA value since no preceding event existed. Negative time differences or other anomalies were checked to ensure data integrity.


##### b. Bot Detection and Removal

• A rule-based approach was employed to identify potential bots by flagging visitors with total event counts in the top 5% or average time differences in the bottom 5%.

• An Isolation Forest model was applied on aggregated features such as total events, average and median time differences. This anomaly detection technique highlighted users whose behaviour patterns deviated significantly from typical user activity.

• Both detection methods were combined and events associated with flagged bot users were removed to ensure that only genuine user behaviour remained in the final dataset.

• After ensuring that the dataset was free of duplicates, missing values and bot-generated noise, the cleaned data was exported as a new CSV file, serving as a reliable foundation for further analysis.

• Once cleaned and standardised, the dataset was exported as a new CSV file.

#### c. Data Processing of Timestamp and Merging Item Properties

• Binding Item Properties Files:
The two parts of the item properties file (part 1 and part 2) were combined into a single data frame. A read-in-chunk approach was applied earlier to manage large files. The code uses the do.call function along with rbind to concatenate the two lists of item property data into one unified dataset.

• Timestamp Conversion:
Timestamps in the item properties dataset were originally in Unix time (milliseconds since the epoch). These were converted to a human-readable POSIXct format using the as.POSIXct function. The division by 1000 adjusts the value from milliseconds to seconds. Specifying the time zone as "UTC" ensures consistency across all timestamp values.

• Preparing Item Properties for Merging:
The item properties dataset, which contains multiple snapshots per item reflecting changes over time, was first sorted by itemid and timestamp to organise the snapshots chronologically. All snapshots were preserved to retain the temporal evolution of item properties rather than reducing the data to one row per item.

#### d. Merging cleaned events dataset and item properties dataset
• Preparing the Events Data for Merging:
The cleaned events dataset was converted into a data.table and sorted by itemid and timestamp. This step aligns the events data with the ordering of the item properties and is essential for performing a left join with a rolling mechanism.

• Merging the Datasets Using a left Join:
A left join was performed with the events file as the primary table. The join was executed on the itemid and timestamp columns with the roll = TRUE parameter. This approach ensures that every event is enriched with the most recent snapshot from the item properties that occurred before or at the time of the event, preserving all events while accurately reflecting the temporal context of each item property snapshot.

• Columns "time_diff", "hour" and "weekday"  were dropped from the merged_df.

In the left joined events_items dataset, the property column was updated to ensure that for rows where property equals "categoryid", the value in the value column replaces property. This step ensures consistency in how category information is stored.

#### e. Data Processing of Category Tree: 
The category_tree dataset was carefully cleaned to ensure its integrity before merging with other datasets.

• There were no duplicates in the category_tree dataset

• Handling Missing Values in parentid: The parentid column contained 25 missing values. Since parentid represents hierarchical relationships between categories, imputing missing values was necessary. The median value of the parentid column was computed and used to replace the missing values. This approach helps maintain the categorical structure while minimising bias.

### Final Merge 
To enrich the events_items dataset with category information, a left join was performed with the category_tree dataset. This ensures that all event records are retained while relevant category details are appended.

#### Procedure: 

• Ensuring Data Type Consistency:
The property column in events_items and the categoryid column in category_tree were converted to character type to prevent mismatches.

• Merging the Datasets: 
A left join was executed, matching the property column from events_items with the categoryid column from category_tree to form a merged_df. This operation retains all records in events_items and adds category details where available.
The final merge was saved as final_data
• Ensuring 'Available' is a Separate Column and Merged into the Final Dataset:

To correctly integrate the availability information into the final dataset, the following steps were performed:

a. Filtering for Availability Properties:
Rows where the property equals "available" were filtered from the merged dataset.

b. Restructuring the Data:
The filtered data was pivoted so that each item had its available status as a separate column. This step converts the long format into a wide format for the "available" property.

c. Converting to Numeric and Integer:
The available column was converted to numeric, with missing values replaced by 0, and then converted to integer (0 or 1).

d. Retaining Only the Latest Available Status:
To avoid multiple records per item, the dataset was grouped by itemid, sorted in descending order by timestamp, and only the most recent available status was retained.

e. Final Merge:
The processed availability data was then merged back into the merged_df to form a final_df via a left join on itemid so that all records from the main dataset were retained and enriched with the latest availability information.

### 4. Exploratory Data Analysis:
##### Visualising the Distribution of User Events
![Image](https://github.com/user-attachments/assets/48c3f9c8-694e-4625-a470-55409074bf3d)

The chart above visualises the distribution of user events, addtocarts, transaction, view.

A. View Events: The view event category has the highest count by significant margin, with a total of 2,644, 218 events. This suggests visitors are viewing items on the platform.

B. Add to Cart Events: There are 68,966 events where visitors or users have added items to their cart. This is a positive sign as it indicates user interest in purchasing, although the number is much lower compared to the events.

C. Transaction Events: This category has the lowest count with 22,457 events. This represents the number of completed transactions, which is a critical metric for revenue generation.

Analysis:

The large number of view events compared to add to carts and transaction events suggest that there might be a drop-off in the conversion funnel (A conversion funnel, also known as a sales funnel or marketing funnel, is a visual representation of the customer journey from the first point of contact with a business to the final purchase or desired action. It's a model used to understand how potential customers move through different stages towards conversion, which is typically a sale but can also be any other desired action like signing up for a newsletter, downloading a whitepaper, purchasing product, et.) 
Users are viewing content but not as many are proceeding to add items to cart or complete transactions.

The ratio of view to transaction events is quite high. This could indicate that there are barriers to conversion, such as high prices, a poor user experience or lack of trust in the platform.

The add to cart events are significantly higher than transactions, which is expected, but the gap is quite large. This could mean that users are adding items to their carts but not completing the purchase. Reasons could include abandoned carts, issues during the checkout process, or the user deciding against the purchase at the last moment.

##### User Event Distribution Visualisation After Anomaly Removal
![Image](https://github.com/user-attachments/assets/df651954-e8de-4038-92f9-fea191527f50)

The charts show the distribution of user events after removing bots. The events tracked are 'view', 'addtocart' and 'transaction'.

#### Key Findings:

##### Views:

Before bot removal: 2,664,218

After bot removal: 1,817,072

Drop: 847,146 (31.8% reduction)

Implication: A significant portion of views were bot-generated, indicating inflated traffic metrics.

##### Addtocart:

Before bot removal: 68,966

After bot removal: 22,947

Drop: 46,019 (66.7% reduction)

Implication: Bots contributed to addtocart actions, but less so compared to views.

##### Transactions:

Before bot removal: 22,457

After bot removal: 5,392

Drop: 17,065 (75.9% reduction)

Implication: Transactions were less affected by bots, suggesting more genuine human actions.


Analysis:

The large drop in views suggests that the website's traffic was significantly inflated by bots, which could affect advertising revenue and perceived popularity.

The drop in addtocart events indicates that user engagement might be lower than initially thought, suggesting a need to improve the user experience or product offerings.

The 75.9% reduction means that bots contributed heavily to transaction counts, but the remaining transactions after bot removal are likely more reliable as genuine human activity. This makes transactions a more trustworthy metric for evaluating real user behaviour, even though the absolute drop was large.



##### Visualising the Top 10 Most Viewed Products and Top 10 Most Purchased Products
![Image](https://github.com/user-attachments/assets/0fd3bc57-c985-4e7f-83f8-f54df70141cb)

The bar chart titled "Top 10 Most Viewed Products" provides insights into product popularity based on view counts. 

Product 187946 dominates with over 3,000 views, far exceeding all other products.
The remaining products have significantly fewer views, ranging from 1,000 to 2,000 views.

![Image](https://github.com/user-attachments/assets/00b7e2d3-b2a4-4ac8-869b-8ed785a487a2)

The bar chart titled "Top 10 Most Purchased Products" reveals key insights into product sales performance.

Product 461686 leads with 24 purchases, followed closely by 7943 with 23 purchases.

Products 48030, 312728, 213834, 17478 form a mid-tier group with 16–17 purchases each.

These products are consistently popular but lag behind the top two.

Products 268883, 416017, 409804, 441852 have 11–12 purchases suggesting lower engagement or appeal

Analysis:

Most Viewed Product (187946): over 3,000 views (from previous data), but not in the top purchased list, indicating a disconnect between interest and purchase.

Top Purchased Products (461686, 7943): 24–23 purchases each, suggesting these items resonate strongly with buyers.

Product 187946 may need optimization (pricing, descriptions or checkout flow) to convert viewers into buyers. Top purchased products could be leveraged for cross-selling or inventory prioritization.


### Answers to key analytic questions:

### How effective is the user funnel?
![Image](https://github.com/user-attachments/assets/fbe4d5c5-8dee-4b06-9bb4-a8add94965af)

The bar chart illustrates the user journey from viewing content to completing a transaction, revealing critical insights about user engagement and conversion rates. The x-axis represents the event types: view, addtocart and transaction. The y-axis represents the count of each event type. The bars are plotted in a way that shows a significant drop-off from views to addtocart, and then again from addtocart to transaction.

#### View dominance:
The "view" event has an extremely high count, indicating substantial initial interest or traffic. This suggests effective marketing in driving users to the platform or content.

#### Significant drop-off to add-to-cart:
There's a dramatic decrease from views to add-to-cart events. This indicates that while many users view content, only a small fraction take the next step of adding items to their cart.

#### Further drop-off to transaction: 
The transition from add-to-cart to transaction shows another substantial decrease. This suggests that even users who express purchase intent by adding items to their cart often don't complete the purchase.

### Implications: 
#### Cart Abandonment: 
The gap between add-to-cart and transaction highlights a common e-commerce challenge: cart abandonment. Reasons might include: Unexpected costs (shipping, taxes), Complicated checkout process, Security concerns, Distractions or interruptions.

#### User Experience Concerns:
The large drop-off may suggest problems in the user interface or journey: Difficulty in navigating from viewing to purchasing, Complicated or lengthy add-to-cart process, Lack of clear calls-to-action.

#### Funnel Efficiency: 
The conversPost-bot removal, the data provides a clearer picture of real user behavior. While views remain high, the conversion funnel highlights opportunities to improve engagement and revenue by focusing on genuine user interactionsion rate from view to add-to-cart is extremely low, indicating potential issues in converting initial interest into concrete actions.

The current funnel suggests opportunities for significant improvement in conversion rates. Even small percentage improvements could yield substantial results given the high volume of views

Post-bot removal, the data provides a clearer picture of real user behavior. While views remain high, the conversion funnel highlights opportunities to improve engagement and revenue by focusing on genuine user interactions

### What are the trends in user activity over time?
![Image](https://github.com/user-attachments/assets/b29b8f56-2d67-4eaa-a26a-cd579ac9671e)

The chart shows monthly total events from May through September, with the y-axis representing total events (up to 22,208) and the x-axis showing dates.

#### Key Observations

#### Overall Range:
This time series visualization reveals several vital patterns in user activity over time. Monthly events fluctuate significantly, ranging from 1000 to 22,000 events per day. This substantial variation suggests user activity is influenced by multiple daily changes.

#### Trend Analysis: 
The latter part of the series (August-September) shows more pronounced fluctuations compared to earlier months. The final data point shows a significant drop to around 1000 events, which might indicate a recent change in user behavior or potential data collection issues.

#### Potential Outliers: 
Several days show unusually high spikes (over 20,000 events) that stand out from the general pattern. These could represent special events, marketing campaigns or system anomalies.

### Implications:
#### Recent Drop Investigation: 
The significant decline near September requires investigation to determine if it represents:

a. A genuine reduction in user interest.

b. Technical issues affecting event tracking.

c. Changes in user behavior following a platform update

#### Marketing Effectiveness:
The peaks may correlate with specific marketing initiatives, suggesting successful campaigns. The valleys could indicate opportunities for improved marketing strategies during traditionally slower periods.

#### User Engagement Variability:
The substantial daily fluctuations suggest user engagement is highly sensitive to external factors such as:

a. Marketing campaigns

b. Seasonal events

c. Product updates

d. External news or trends

### When are users most active?
![Image](https://github.com/user-attachments/assets/66d962a4-cfc1-4b83-ab65-938c8afd6d99)

The heatmap shows event counts across different hours of the day and weekdays. 

Key Observations:

#### Peak Activity Periods:
- User activity peaks in the late afternoon to evening hours (15:00 - 21:00).
- The highest concentration of events occurs between 17:00 and 20:00 across most weekdays
- Early morning (0:00 - 6:00) shows consistently low activity.

#### Day Patterns
- Early morning shows consistently low activity.
- Mid-morning to early afternoon has no activity.
- Evening hours display the highest activity levels.

#### Weekday Differences:
- Saturday evenings appear to have sustained low activity.
- Monday through Thursday show similar patterns with peak activity in the late afternoon/evening.

#### Implications:

Marketing Timing: 
- Avoid sending important communications during low-activity periods when users are less likely to engage.
- Time-sensitive promotions or notifications would be most effective during peak activity periods.

Content Scheduling: New content or features should be launched during peak times to maximize immediate engagement.

User Experience: 
- Ensure platform performance is optimized during high-traffic periods to prevent slowdowns.


### How does the availability of items impact user interactions?
![Image](https://github.com/user-attachments/assets/bdd9b61e-6f4f-4fc6-9388-a2b457e29ba3)

This bar chart compares user interactions with available versus unavailable items across three key event types: views, add-to-carts and transactions.

#### Key Observations:

Views: 
- Available items receive dramatically more views than unavailable items.
- The green bar (available) is significantly taller than the red bar (unavailable), indicating users are much more likely to view available items.

Add-to-Cart: 
- Available items also show higher add-to-cart events compared to unavailable items.
- While the difference is less pronounced than with views, there's still a clear preference for adding available items to carts.

Transactions:
- Transactions for unavailable items are extremely rare, nearly non-existent.
- The red bar for transactions is barely visible, showing minimal purchases of unavailable items.

Implications: 

User Behavior:
- Users strongly prefer interacting with available items at every stage of the conversion funnel.
- Unavailable items generate minimal engagement beyond initial views, with virtually no conversions.

Inventory Management:
- Ensuring item availability is critical for driving user engagement and conversions.
- Stockouts significantly reduce opportunities for both add-to-carts and transactions.

User Experience: 
- Displaying unavailable items may frustrate users who attempt to purchase them.
- The presence of unavailable items in search results or recommendations might negatively impact the overall experience.


### How do conversion rates vary across different times of the day?
![Image](https://github.com/user-attachments/assets/88360be9-14d7-4158-ab51-b4ce67c59187)

This line chart illustrates how conversion rates for two key metrics view-to-add and add-to-purchase fluctuate throughout the day.

#### Key Observations:

View-to-Add Conversion Rate:

- Remains relatively stable throughout the day, maintaining a consistent rate just below 0.1 (10%).
- Shows minimal fluctuation, suggesting consistent effectiveness in converting views to add-to-cart actions regardless of time.

Add-to-Purchase Conversion Rate:
- Exhibits significant variability throughout the day.
- Peaks occur more prominently in the late afternoon to evening (4-8 PM).
- The highest conversion rate reaches above 0.25 (25%) around 5 PM.
- Conversion rates dip to their lowest points during midday.

Comparison Between Conversion Types:

- Add-to-purchase conversions show much greater temporal variation compared to view-to-add conversions.
- The peak add-to-purchase conversion rate is more than double the relatively stable view-to-add rate.

Implications: 
- Users are more likely to complete purchases during specific periods, particularly in the late afternoon and evening.
- This may reflect patterns in when users have time to complete purchases, such as after work or during evening leisure time.
- The consistent view-to-add conversion rate suggests that users are equally likely to add items to their cart regardless of time of day.
- This indicates that the decision to add an item to a cart is less time-sensitive than the decision to complete a purchase.
- The afternoon/evening peak could correspond with times when users have access to multiple devices (work and personal).
- There may be opportunities to optimize marketing efforts during these high-conversion periods.


### What is the relationship between user session duration and purchase likelihood?
![Image](https://github.com/user-attachments/assets/03f62622-c2e2-4a4c-bf00-dcb2fdb1513c)

This bar chart examines whether longer session durations correlate with higher conversion rates. 
#### Key Observations:
Peak Conversion Rate: 

- The highest conversion rate occurs in the 5-10 minute session duration bin (~0.03 or 3%).
- This suggests users who spend 5-10 minutes on the platform are most likely to convert.

Declining Conversion Rates:

- Conversion rates decrease for sessions shorter than 5 minutes and longer than 10 minutes.
- The longest sessions (30+ minutes) have the lowest conversion rate (~0.005 or 0.5%), similar to the shortest sessions.

Non-Linear Relationship: 
- The relationship between session duration and conversion rate is not linear.
- There's an optimal session duration window (5-10 minutes) where conversion rates are maximized.

Implications:

User Intent:  
- Users who spend 5-10 minutes might be more intentional about their actions, completing purchases efficiently.
- Very short sessions may represent users who leave quickly without engaging.
- Very long sessions might indicate browsing without purchase intent or difficulty navigating the platform.

Experience Optimization: 
- The platform should be optimized to help users find what they need efficiently, preventing both overly short and excessively long sessions.
- Streamlining the user journey could help convert short-session users who might be leaving due to frustration or lack of engagement.



## Modelling



## Evaluation


## Recommendations 
### The Top Purchased Products and Viewed Products

#### 1. Optimize High-View Products: 

Improve descriptions, images or pricing for product 187946 to boost conversions.

#### 2. Engage Infrequent Users: 

Use targeted campaigns (discounts, personalized recommendations) to re-activate users with low engagement.


### The User Funnel Analysis
#### 1. Optimize Conversion Pathways: 
a. Simplify the process from viewing to adding to cart

b. Implement clear, prominent calls-to-action

c. Ensure mobile-friendly design

d. Focus on the add-to-cart stage as a critical leverage point for increasing transactions

#### 2. Address Cart Abandonment:
a. Implement cart abandonment email campaigns

b. Offer incentives for completing purchases

c. Provide multiple payment options

d. Display trust signals during checkout

#### 3. Personalization:
a. Use data to personalize recommendations

b. Show relevant products based on user behavior

c. Implement dynamic pricing or special offers.

### Strategic Considerations
The current funnel suggests opportunities for significant improvement in conversion rates. Even small percentage improvements could yield substantial results given the high volume of views. Focus on the add-to-cart stage as a critical leverage point for increasing transactions. 

#### 4. Analytics and Testing:
a. Gather user feedback to identify specific pain points

### Monthly Total Events Analysis:
a. Investigate Recent Decline:
- Determine the cause of the recent drop in events
- Check for technical issues in event tracking
- Review recent platform changes that might affect user behavior
- Analyse user feedback for potential concerns

b. Correlate with External Factors:
- Overlay marketing campaigns, product launches and external events on the time series to identify drivers of peaks and valleys.
- Analyse how specific initiatives impact user engagement.

c. Implement Real-Time Monitoring:
- Create dashboards to monitor key metrics in real-time

### User Activity Analysis: 
Implement Time-Based Strategies:
- Create targeted marketing campaigns that align with peak activity windows.
- Develop special weekend promotions to leverage Saturday and Sunday engagement patterns.

Analyse Event Types: Identify if certain activities peak at different times than others.

### User Interactions on Items Availability Analysis:
- Prioritise displaying available items in search results and recommendations.
- Consider removing or deprioritising unavailable items from user-facing interfaces.
- For unavailable items, provide clear messaging about restock dates or alternatives for user communication.
- Implement notification systems for when unavailable items become available again.

### Conversion Rates by Hour of the Day Analysis:
- Schedule promotional emails or notifications during peak conversion hours (4-8 PM) when users are most likely to complete purchases.
- Consider offering time-limited discounts during these periods to further incentivize purchases.
- Ensure customer service and support teams are adequately staffed during peak conversion hours to handle potential inquiries.
- Optimize website performance during these critical periods to prevent technical issues that could hinder conversions.
- Correlate these conversion patterns with traffic sources to determine if certain channels drive more conversions during specific times.
