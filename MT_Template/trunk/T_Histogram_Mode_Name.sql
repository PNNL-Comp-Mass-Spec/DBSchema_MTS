/****** Object:  Table [dbo].[T_Histogram_Mode_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Histogram_Mode_Name](
	[Histogram_Mode] [smallint] NOT NULL,
	[Histogram_Mode_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Histogram_Mode_Name] PRIMARY KEY CLUSTERED 
(
	[Histogram_Mode] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
