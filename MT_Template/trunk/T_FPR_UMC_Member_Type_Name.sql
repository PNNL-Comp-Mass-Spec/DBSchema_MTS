/****** Object:  Table [dbo].[T_FPR_UMC_Member_Type_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FPR_UMC_Member_Type_Name](
	[Member_Type_ID] [tinyint] NOT NULL,
	[Member_Type_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_FPR_UMC_Member_Type_Name] PRIMARY KEY CLUSTERED 
(
	[Member_Type_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
