/****** Object:  StoredProcedure [dbo].[MassTagAccumulationTrend] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE MassTagAccumulationTrend
/****************************************************
**
**	Desc: 
**		Generates data showing number of PMT Tags
**		present over time in given DB
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 05/26/2005
**			  11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',
	@MinimumPMTQualityScore real = 1,
	@MinimumHighDiscriminantScore real = 0
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @Sql varchar(8000)

	declare @result int
	declare @stmt nvarchar(256)
	declare @params nvarchar(256)
	set @stmt = N'exec [' + @MTDBName + N'].dbo.MassTagAccumulationTrend @MinimumPMTQualityScore, @MinimumHighDiscriminantScore'
	set @params = N'@MinimumPMTQualityScore real, @MinimumHighDiscriminantScore real'
	exec @result = sp_executesql @stmt, @params, @MinimumPMTQualityScore = @MinimumPMTQualityScore, @MinimumHighDiscriminantScore = @MinimumHighDiscriminantScore

	Set @myError = @result
Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[MassTagAccumulationTrend] TO [DMS_SP_User]
GO
