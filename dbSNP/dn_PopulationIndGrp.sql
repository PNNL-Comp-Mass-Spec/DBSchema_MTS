/****** Object:  Table [dbo].[dn_PopulationIndGrp] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dn_PopulationIndGrp](
	[pop_id] [int] NOT NULL,
	[ind_grp_name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ind_grp_code] [tinyint] NOT NULL
) ON [PRIMARY]

GO
