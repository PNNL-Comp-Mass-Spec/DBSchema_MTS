/****** Object:  Table [dbo].[T_DMS_Filter_Set_Criteria_Names_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Filter_Set_Criteria_Names_Cached](
	[Criterion_ID] [int] NOT NULL,
	[Criterion_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_DMS_Filter_Set_Criteria_Names_Cached] PRIMARY KEY CLUSTERED 
(
	[Criterion_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
