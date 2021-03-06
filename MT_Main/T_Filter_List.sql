/****** Object:  Table [dbo].[T_Filter_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Filter_List](
	[Filter_ID] [int] NOT NULL,
	[Name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Description] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[P1] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[P2] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Filter_Method] [varchar](12) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Filter_List] PRIMARY KEY CLUSTERED 
(
	[Filter_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
