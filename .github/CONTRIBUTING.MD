# Contributing guidelines

1. Create a fork of the repository
1. Create a feature branch for your issue or new feature. Ideally you will have raised an issue first and the commit will be referencing the issue or feature request.
1. Push into a feature branch
1. Create a pull request into the current default branch. The default branch will be one currently being in development.
1. I will then merge it into master providing the review and all tests are passed.

# Code formatting
Different styles work for different people. I am not religious about formatting and genereally happy with anything as long as it's sensible. Formatting tools allow easy customatisation. However, it would be good to be consistent across the project despite some questionable rules, such as the lowercase syntax. I realise this is unpopular in T-SQL world but it has been inherited with the original code base so too late to change it now.

# Branching strategy
I decided on a slightly different branching strategy for this project. 

In a usual application development there would be a master, development and ad-hoc feature branches. Master would normally hold the current "production" release and development branch would hold the next release "work in progress". Feature branches would hold hot fixes or new features being added by the community, then merged into development by the maintainer.

Instead, SQLWATCH branches correspond with the version: `3.x`. The current branch will be one currently being worked on, i.e. the "development" branch. I will be making frequent releaes based on the PRs rather than waiting for another big release like in versions 2.x. 
