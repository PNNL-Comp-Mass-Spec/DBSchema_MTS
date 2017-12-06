/****** Object:  Table [dbo].[BlitzFirst_FileStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BlitzFirst_FileStats](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CheckDate] [datetimeoffset](7) NULL,
	[DatabaseID] [int] NOT NULL,
	[FileID] [int] NOT NULL,
	[DatabaseName] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[FileLogicalName] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TypeDesc] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SizeOnDiskMB] [bigint] NULL,
	[io_stall_read_ms] [bigint] NULL,
	[num_of_reads] [bigint] NULL,
	[bytes_read] [bigint] NULL,
	[io_stall_write_ms] [bigint] NULL,
	[num_of_writes] [bigint] NULL,
	[bytes_written] [bigint] NULL,
	[PhysicalName] [nvarchar](520) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_C2EA6C29-3035-4D36-A739-4116C2759C8F] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
