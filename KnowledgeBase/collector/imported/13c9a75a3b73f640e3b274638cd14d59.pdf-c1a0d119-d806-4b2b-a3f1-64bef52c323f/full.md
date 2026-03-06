Write
Get unlimited access to the best of Medium for less than $ 1 /week. Become a member
Say Hello to Grafana OnCall
A Practical Guide to Grafana OnCall
Magsther Follow 8 min read · Jun 11, 2023
125
Introduction
In this post, I’ll take a closer look at Grafana OnCall and demonstrate how
you can use it as an on-call management tool.
What is Grafana OnCall?
Grafana OnCall is an on-call management tool that is available in Grafana
Cloud and Grafana OSS (Open Source).
Grafana OnCall gives a central view of all incidents and allows you to quickly
see and update the status of incidents and search for older resolved
incidents.
Grafana OnCall — Components
Before we continue, it’s important that you know about the different pieces
and learn the terminology. That is especially true, if you are coming from
other on-call management tools like PagerDuty.

Here is an overview of the components.
Integrations (Alert Detection)
Integrations is how you connect a service / application to send alerts to
Grafana OnCall.
These are the characteristics of Integrations:
Connects to a monitoring system
Examples can be Alertmanager, Webhooks, Datadog
Some of the integrations are supported
For other integrations, you will probably need to create webhooks .
Alert Grouping
With Alert grouping, Grafana OnCall receives alerts, groups them and routes
them according to configurable alert grouping and escalation steps. This
prevent alert storms and reduce the noise your teams are exposed to during
an incident.
Escalations (Alert Routing)
Escalation Chains are created to determine alerts are going to be handled.
You create chains (steps) to specify who is going to notified for an alert.

Based on the payload from the alerts, you can configure routes to send to
different escalation chains. This helps to ensure that the alerts are going to
the correct escalation and prevent alerts from being missed. There might be
cases, when you monitors that have different severity (warnings, critical etc.)
By using routes, we can route the these alerts to different channels based on
the payload of the alerts.
Once the alert is then triggered , it will be sent to one of the notifications
methods.
These are the characteristics of Escalations:
How users and groups are notified when an alert notification is created.
Notification Method (slack, sms, email , phone)
Escalation Chains (steps that are followed in order when a notification is
triggered)
A route (based on the metadata within the alert payload)
Schedules (Notifications)
An on-call schedule consist of one or more rotations that contain on-call
shifts.
These are the characteristics of Schedules:
A list of people that should be part of an on-call schedule
Shifts (a period when an individual user is on-call)
Connect the shift to a schedule
Include the schedule in the escalations
Getting Started
An easy way to get started with Grafana OnCall is to sign up for a free trial
account on Grafana Cloud , which is the SaaS version of Grafana.

Once you have signed in and logged in, click on Alerts & IRM -> OnCall

Right now we don’t have any alert groups. Let’s change that by first creating
an integration.
Integrations
As mentioned above, integrations is how you connect a service / application to
send alerts to Grafana OnCall.

To create an integration, click on the New integration to receive alerts
button.
Select an integration from the list.
Grafana OnCall can connect directly to the monitoring services where your
alerts originate. All currently available integrations are listed in the Grafana
OnCall Create Integration section.

If the integration you’re looking for isn’t currently listed, you can always use
one of the Webhook integrations, which we will use in this case.
What’s a webhook?
The Webhook is the Web’s way to integrate completely different systems in semi-
real time. As time has passed, the Web (or more precisely, HTTP , the protocol used
for requesting and fetching the Web site you’re currently reading) has become the
default delivery mechanism for almost anything that’s transferred over the
Internet.
Our new webhook integration, will give us an unique webhook URL ( as well
as tips on how to start sending alerts to Grafana OnCall from our monitoring
system.

I always click on Send demo alert, to verify that the integration works. The
alert will be sent to Grafana OnCall and you can find the test alert in the
Alert Groups tab.
You can now find your alerts on the Alert Groups page.
Clicking on the incident will give you further details about the incident.

Escalation Chains
Once the integration is created and you are able to send alerts into Grafana
OnCall, the next step is to setup an Escalation Chain to determine how these
alerts are going to be handled.
An escalation chain can have many steps, or only one step.
To do that, go to the Escalation Chains page and create new chain.
Here, I’ve created two escalation chains; one for critical alerts and one for
warnings. Next step is to decided what this chain will do. It can contain one
or more steps. To showcase how this work, I’ll first notify a user (me), wait 5
minutes and then resolve the incident automatically.
If you scroll further down the list, you will see that you can add more
advanced steps.

For now we are good, so now we need to link this escalation chain to an
Integration.
Back on the integrations page, we pick the escalation chain that we want to
use.
From this page, you can now add additional steps in your escalation chain.

Next time an alert is sent to this integration, it will use the linked escalation
chain. But how does Grafana knows what for notification the user has? Well,
you need to set this up on the user page.
As you can see, you can select how you would like to get notified in Default
Notifications.
You can on this page also add your phone number, connect a Slack
integration, Teams connection and as you can see a Mobile connection :)

Schedules
As mentioned at the beginning of this post, an on-call schedule consist of
one or more rotations that contain on-call shifts.
A schedule must be referenced in the corresponding escalation chain for alert
notifications to be sent to an on-call user.
A fully configured on-call schedule consists of three main components:
Rotations : A recurring schedule containing a set of on-call shifts that
users rotate through.
On-call shifts : The period of time that an individual user is on-call for a
particular rotation
Escalation Chains : Automated steps that determine who to notify of an
alert group.

To create a new schedule , go to the Schedules page
We want to create the schedule using the Grafana OnCall UI, so we use the
Set up on-call rotation schedule
Give a name to the schedule and pay attention to the other options on this
page. It’s quite nice to get notifications and information about the oncall
shifts in a Slack channel.

The schedule is created, and now we need to setup some rotation, which
means adding users to the schedule.

Here, I’ve added a new rotation and added one user to the schedule.
Once I click Create, the schedule is being created.

Note, there are many options that you can add here and in a production system,
you will need to carefully set these accordingly.
Adding a schedule to an Escalation Chain
It’s starting to look good, and we have all the pieces configured.
Now let’s add the newly created schedule to an Escalation Chain.
Add the step called “ Notify users from on-call schedule ”, and select the
schedule from the list.

As you will notice, you can drag and drop the steps how you want. Here, I’ve
put the “ notification for schedule ” to the top.
When should I use Grafana OnCall?
For any greenfield projects, I’d say that Grafana OnCall is a no-brainer. It’s
easy to setup and manage and includes the necessary features and functions
that other products uses. The documentation of how to use the tool is
straightforward, but should you need any missing feature, a new issue can be
created on their GitHub page.
For greenfield projects, Grafana OnCall should be
considered as a no-brainer tool to achieve your goal

The support from the OnCall engineers is great, and you can join their
community calls to ask questions.
What if I use another on-call management tool?
Many organisations already uses other tools, like PagerDuty. The Grafana
OnCall team provides a migration tool that helps you to migrate PagerDuty
configuration to Grafana OnCall.
Conclusion
In this post, we looked at Grafana OnCall which is an on-call management
tool available in Grafana Cloud and Grafana OSS (Open Source).
Grafana OnCall gives a central view of all incidents and allows you to quickly
see and update the status of incidents and search for older resolved
incidents.
I hope you liked this post. If you found this useful, please hit that clap
button and follow me to get more articles on your feed.
Grafana Development Incident Management Software Engineering
Open Source
125
Written by Magsther Follow
796 followers · 4 following
Creator of “Awesome OpenTelemetry”. https://twitter.com/magsther
No responses yet

Wnlin
What are your thoughts?
Cancel Respond
More from Magsther
Magsther Magsther
Grafana Alloy & OpenTelemetry How to Create and Host a Website
with Hugo and GitHub Pages Say Hello to Alloy
GitHub Pages + Hugo
May 18, 2024 132 3 Jun 18, 2023 206 4
Magsther In FAUN.dev — Developer Community by Magsthe
￰ r
JupyterHub on Kubernetes Grafana dashboards as
ConfigMaps An introduction to JupyterHub
Grafana Dashboard as Code
Dec 30, 2022 31 Aug 19, 2022 10
See all from Magsther

Recommended from Medium
Think, Write, Repeat Kedarnath Grandhe
How to send and query metrics Grafana Mimir as a long term
to/from Grafana Mimir storage for Prometheus metrics —
Part 2 Two Ways to Send Metrics to Grafana Mimir As mentioned in the previous blog, we are
here with Part 2 of the Mimir series and this
part covers deployment methods and hands
on… Apr 17 1 Feb 23 7
Mahernaija Batuhan Bulut
OpenTelemetry Ultimate Guide : Kubernetes Logging with
With Python demo exemples OpenTelemetry + Traces
How to Trace, Monitor, and Log Everything in Kubernetes Logging and Tracing with Open
Your Cloud-Native Apps with One Powerful Telemetry
Framework
Aug 3 24 Jun 17 2
In System Weakness by The Outage Specialist Mochamad Gufron
Securing Java APIs with OAuth2 Troubleshooting #3: Alloy + Loki —
and Keycloak (Beyond the Basics) A Love Story with Silly Mistakes

The lessons we learned implementing real- Not long ago, life was simpler. If you needed
world SSO to ship logs to Loki, the answer was always
Promtail — unless you were outside
Kubernetes… Jul 14 7 1 May 4 1
See more recommendations
Help Status About Careers Press Blog Privacy Rules Terms Text to speech

