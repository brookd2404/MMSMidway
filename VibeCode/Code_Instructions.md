# Copilot Vibe-Coding Brief

Use this file as the task brief when asking GitHub Copilot to implement a solution in this repository. Fill in the sections relevant to the task, then ask Copilot to inspect the codebase and make the changes.

## Task

<!-- Describe what you want Copilot to build or fix. -->

I want to build a simple web application for IT Helpdesk staff for certain tasks on Intune devices, such as getting BitLocker recovery keys, checking device compliance, and performing remote actions like wipe or restart. The application should have a user-friendly interface and integrate with Microsoft Graph API to perform these tasks.

This should be a SWA, and be very intuitive for IT Helpdesk staff to use. The application should have a login system that authenticates users against Azure AD, and only allows authorized users to access the features using their Delegated access permissions. The application should also have a logging system to track user actions and any errors that occur.

This should not be something that requires a lot of clicks, maybe a simple search bar to search for a device by name or ID, and then a list of actions that can be performed on that device. The application should also have a dashboard that shows the status of devices, such as compliance status, last check-in time, and any alerts or issues. If possible, try and auto-complete the search bar with device names or IDs as the user types, to make it even easier to find devices.

## Desired outcome

<!-- Describe how the solution should behave from the user's perspective. -->

A SWA that can be published to Azure, with a simple and intuitive interface for IT Helpdesk staff to perform tasks on Intune devices. The application should allow users to search for devices by name or ID, view device details, and perform actions like getting BitLocker recovery keys, checking compliance status, and performing remote actions. The application should also have a dashboard that shows the status of devices and any alerts or issues. The application should be responsive and accessible, and should log user actions and errors.

## Requirements

- Meet the task and desired outcome above.
- Inspect relevant code before editing; reuse existing functionality where possible.
- Preserve existing behavior unless the task explicitly requires a change.
- Keep changes focused; do not modify unrelated files or perform unrelated refactoring.
- Handle relevant edge cases and errors consistently with the project.

## Constraints

- Target platform/runtime: Vite React/Type Script
- Dependencies or tools: Node.JS, React, TypeScript, Material UI, Microsoft Graph API
- Compatibility, security, or performance needs: <!-- Specify, or leave blank. -->
- Other limitations: Material UI library should be used for the frontend components, and the application should be responsive and accessible.

## Acceptance criteria

- [ ] The requested behavior is implemented.
- [ ] Relevant existing behavior remains intact.
- [ ] Focused tests are added or updated when appropriate.
- [ ] Relevant build, test, or lint checks pass.

## Validation commands

<!-- Add the commands Copilot should run, if known. -->

## Copilot instructions

First inspect the relevant parts of the repository. Then implement the smallest complete solution that satisfies this brief. Run appropriate validation and report the files changed, checks run, and any remaining limitations. If requirements conflict or an essential detail is missing, state the assumption you used rather than expanding the scope.
