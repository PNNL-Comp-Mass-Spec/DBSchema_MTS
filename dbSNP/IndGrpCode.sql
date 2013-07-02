/****** Object:  Table [dbo].[IndGrpCode] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IndGrpCode](
	[code] [tinyint] NOT NULL,
	[name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[descrip] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]

GO
