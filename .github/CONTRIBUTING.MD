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

Instead, SQLWATCH branches correspond with the version: `2_3`, `2_4` and so on. The current branch will be one currently being worked on, i.e. the development branch. Once the development is completed I make into a release and once released, I create a new branch for the next version. For example, the current branch is `2_4` which means any features that we want to be released in version 2.4 go into this branch. One 2.4 is realeased I will move onto `2_5` branch.

## Why such approach?
There is always more than one way to skin a cat. Databases are all about integrity and due to referential integrity (foreign keys, schemabound views, procedures) it is often difficult to simply work on a single table without affecting other objects. The same applies to SSIS. For that reason feature branches can often create a lot of merge conflicts. This approach works well for smaller teams, if SQLWATCH grows to have hundreds of contributors then will review the breanching strategy.
