# Contributing guidelines

1. Create a fork of the repository. This will create a copy of the entire repository in your own GitHub account.
1. Create a feature branch for your change in your fork. 
1. Make required changed to the code in your fork.
1. Commit code into the feature branch in your fork.
1. Push the commit from your local work station to the GitHub repository.
1. Create a pull request from your work into SQLWATCH default branch (main). 
1. I will then merge it into master providing the review and all tests have passed.

# Pull Requests guidelines

1. Pull request must reference an existing issue. If you are developing a new feature, please create an issue first and explain what the new feature will entail. This way we can have a discussion before any development work starts.
1. Pull request must indicate whether it's a bug fix, new feature or a maintenance change. This is to allow bots to create automated release notes and documentation so we can all focus on the code rather than paperwork. I am using the release-drafter bot that will attempt to auto-categorise pulls based on regex explained below. Alternatively you can assign label to the PR yourself when you create the Pull Request.
1. Pull request must pass all code validations before it can be merged. If you believe some validations are pointless, please talk to me. There is a bunch of automated validations that sometimes may not make sense but let's have some consistency.
1. Pull request must pass all automated builds and testing before it can be merged. This is unconditional and designed to make sure the code you are checking in will work across different configurations and editions of SQL Server.

Following pull request guidelines is critical for the automated builds and release notes to work.

## Automated categorisation
The release-drafter bot is relying on the below regex to assign categories:
```
autolabeler:
  - label: 'chore'
    files:
      - '*.md'
    branch:
      - '/docs{0,1}\/.+/'
  - label: 'bug'
    branch:
      - '/fix\/.+/'
    title:
      - '/fix/i'
  - label: 'enhancement'
    branch:
      - '/feature\/.+/'
    body:
      - '/JIRA-[0-9]{1,4}/'
```

which are then assigned to the following categories:

```
categories:
  - title: 'Features'
    labels:
      - 'feature'
      - 'enhancement'
  - title: 'Bug Fixes'
    labels:
      - 'fix'
      - 'bugfix'
      - 'bug'
  - title: 'Maintenance'
    label: 'chore'
```

This allows for PR to be categorised as either a BugFix, Maintenance or Feature to make it easier for users to understand what has changed and to assess potential impact on their end.

# Code formatting

Different styles work for different people. I am not religious about formatting and generally happy with anything as long as it's sensible and justified. I am relying on automated code validation to make sure we are following a certain standard. The project has started some time ago using lowercase T-SQL and although I realise 99% of SQL Developers prefer upper case, I am not going to change the entire project now. It's too late, sorry. We have to deal with lowercase and I would rather have all lowercase than a mix of upper and lower. So please, if possible, stick to lowercase T-SQL for consistency. 

# Branching strategy

The default brach is "main" and should always contain the most up to date code. There is a risk with SQL Project that when working on multiple features in separate branches, we may have a conflict of the `*.sqlproj` file as this file contains definition of all used objects.
It should not happen often but we are going to have to deal with it when it happens. I have not found any way of dealing with this in a Git friendly manner. 

Features branches should follow the naming standard described in the Pull Request Guidelines. For bug fixes, name your branch fix-xx where xx is the issue number. For new features, name your branch feature-xx where xx is the issue id describing new feature. Maintenance category will only apply to `*.MD` files or documentation. 
