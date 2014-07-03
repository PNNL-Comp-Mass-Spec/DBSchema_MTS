/****** Object:  Table [dbo].[T_MMD_Match_Score_Mode] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MMD_Match_Score_Mode](
	[Match_Score_Mode] [tinyint] NOT NULL,
	[Match_Score_Mode_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_MMD_Match_Score_Mode] PRIMARY KEY CLUSTERED 
(
	[Match_Score_Mode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
