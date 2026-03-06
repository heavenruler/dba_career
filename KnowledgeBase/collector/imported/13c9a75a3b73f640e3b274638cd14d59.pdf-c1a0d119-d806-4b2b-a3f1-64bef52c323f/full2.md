# Say Hello to Grafana OnCall
A Practical Guide to Grafana OnCall

By Magsther — Jun 11, 2023 — 8 min read

## Introduction
In this post I’ll take a closer look at Grafana OnCall and demonstrate how you can use it as an on-call management tool.

## What is Grafana OnCall?
Grafana OnCall is an on-call management tool available in Grafana Cloud and Grafana OSS (Open Source). It provides a central view of all incidents, lets you quickly see and update incident status, and search for older resolved incidents.

## Grafana OnCall — Components
Before continuing, it’s important to understand the different pieces and terminology, especially if you’re coming from other on-call management tools like PagerDuty.

Overview of the components:

### Integrations (Alert Detection)
Integrations connect a service or application to send alerts to Grafana OnCall. Characteristics:
- Connects to a monitoring system (examples: Alertmanager, Webhooks, Datadog)
- Some integrations are supported directly; for others you’ll use a webhook

### Alert Grouping
Alert grouping means Grafana OnCall receives alerts, groups them, and routes them according to configurable grouping and escalation steps. This helps prevent alert storms and reduces noise during incidents.

### Escalations (Alert Routing)
Escalation chains determine how alerts are handled. You create chains (steps) to specify who will be notified for an alert. Based on alert payload metadata you can configure routes to send alerts to different escalation chains, ensuring alerts go to the correct channel and are not missed. Different severity levels (warning, critical, etc.) can be routed to different channels.

When an alert is triggered it will be sent via one of the notification methods. Characteristics:
- How users and groups are notified when an alert is created
- Notification methods: Slack, SMS, email, phone
- Escalation chains: ordered steps followed when a notification is triggered
- Routes: determined by metadata within the alert payload

### Schedules (Notifications)
An on-call schedule consists of one or more rotations that contain on-call shifts. Characteristics:
- A list of people that should be part of a schedule
- Shifts: periods when an individual user is on-call
- Shifts are connected to a schedule and the schedule is included in escalations

## Getting Started
An easy way to get started is to sign up for a free trial account on Grafana Cloud (the SaaS version of Grafana). After signing in, go to Alerts & IRM → OnCall.

If you don’t have any alert groups yet, create an integration first.

## Integrations
Integrations are how you connect a service or application to send alerts to Grafana OnCall.

To create an integration:
1. Click New integration to receive alerts.
2. Select an integration from the list.

Grafana OnCall can connect directly to the monitoring services where your alerts originate. If the integration you need isn’t listed, use a Webhook integration.

What’s a webhook?
A webhook is a web mechanism to integrate different systems in semi-real-time. It uses HTTP as the delivery mechanism. A webhook integration will give you a unique webhook URL and tips on how to send alerts to Grafana OnCall from your monitoring system.

I recommend clicking Send demo alert to verify the integration works. The test alert will appear in the Alert Groups tab, and you can click the incident to see further details.

## Escalation Chains
After creating an integration and sending alerts into Grafana OnCall, set up an escalation chain to determine how those alerts are handled.

An escalation chain can have many steps or just one. To create one:
1. Go to the Escalation Chains page and create a new chain.
2. Define the steps. For example: notify a user, wait 5 minutes, then resolve the incident automatically.

You can add more advanced steps as needed. After creating the chain, link it to the integration on the integrations page by selecting the escalation chain you want to use. Future alerts sent to this integration will use the linked escalation chain.

User notification preferences are managed on the user page. There you can select Default Notifications, add a phone number, connect Slack or Teams, and configure mobile notifications.

## Schedules
An on-call schedule must be referenced in the corresponding escalation chain for alert notifications to be sent to an on-call user.

A fully configured on-call schedule consists of three main components:
- Rotations: recurring schedules containing a set of on-call shifts that users rotate through
- On-call shifts: the period of time an individual user is on-call for a particular rotation
- Escalation chains: automated steps that determine who to notify for an alert group

To create a schedule:
1. Go to the Schedules page and choose Set up on-call rotation schedule.
2. Give the schedule a name and review the other options (for example, posting notifications to a Slack channel).
3. Add a rotation and add users to the rotation, then create the schedule.

There are many options to configure; in production you should set these carefully.

### Adding a Schedule to an Escalation Chain
Add a step called “Notify users from on-call schedule” and select the schedule from the list. You can drag and drop steps to order them; for example, place the schedule notification step at the top.

## When should I use Grafana OnCall?
For greenfield projects, Grafana OnCall is a strong choice: it’s easy to set up and manage and includes the necessary features found in other products. The documentation is straightforward, and missing features can be requested via the project’s issue tracker. The OnCall engineering team provides good support and community calls for questions.

## What if I use another on-call management tool?
If you already use another tool such as PagerDuty, the Grafana OnCall team provides a migration tool to help migrate PagerDuty configurations to Grafana OnCall.

## Conclusion
Grafana OnCall is an on-call management tool available in Grafana Cloud and Grafana OSS. It gives a central view of incidents, allows quick status updates, and makes it easy to search resolved incidents. For many projects, especially new ones, it’s a solid, easy-to-manage option for on-call management.

Written by Magsther — Creator of "Awesome OpenTelemetry"