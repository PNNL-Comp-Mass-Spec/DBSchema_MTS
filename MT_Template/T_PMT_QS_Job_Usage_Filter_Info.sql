/****** Object:  Table [dbo].[T_PMT_QS_Job_Usage_Filter_Info] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_PMT_QS_Job_Usage_Filter_Info](
	[Filter_Set_Info_ID] [int] IDENTITY(1,1) NOT NULL,
	[Filter_Set_Info] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Filter_Set_ID] [int] NOT NULL,
	[PMT_Quality_Score] [int] NOT NULL,
 CONSTRAINT [PK_T_PMT_QS_Job_Usage_Filter_Info] PRIMARY KEY CLUSTERED 
(
	[Filter_Set_Info_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
