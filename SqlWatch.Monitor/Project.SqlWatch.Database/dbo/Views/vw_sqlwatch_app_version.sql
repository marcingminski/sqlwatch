CREATE VIEW [dbo].[vw_sqlwatch_app_version] with schemabinding
	AS 
select [install_sequence], [install_date], [sqlwatch_version]

,major = parsename([sqlwatch_version],4)
,minor = parsename([sqlwatch_version],3)
,patch = parsename([sqlwatch_version],2)
,build = parsename([sqlwatch_version],1)
from [dbo].[sqlwatch_app_version]
where [install_sequence] = (
	select max([install_sequence])
	from [dbo].[sqlwatch_app_version]
	)
