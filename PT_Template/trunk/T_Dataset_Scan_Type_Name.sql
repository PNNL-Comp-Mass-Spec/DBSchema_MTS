/****** Object:  Table [dbo].[T_Dataset_Scan_Type_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Dataset_Scan_Type_Name](
	[Scan_Type] [tinyint] NOT NULL,
	[Scan_Type_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Dataset_Scan_Type_Name] PRIMARY KEY CLUSTERED 
(
	[Scan_Type] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
