/****** Object:  Database [MTS_Master] ******/
CREATE DATABASE [MTS_Master] ON  PRIMARY 
( NAME = N'MTS_Master', FILENAME = N'I:\SQLServerData\MTS_Master_data.mdf' , SIZE = 109504KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 LOG ON 
( NAME = N'MTS_Master_log', FILENAME = N'H:\SQLServerData\MTS_Master_log.ldf' , SIZE = 204096KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO
ALTER DATABASE [MTS_Master] SET COMPATIBILITY_LEVEL = 100
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [MTS_Master].[dbo].[sp_fulltext_database] @action = 'disable'
end
GO
ALTER DATABASE [MTS_Master] SET ANSI_NULL_DEFAULT ON 
GO
ALTER DATABASE [MTS_Master] SET ANSI_NULLS ON 
GO
ALTER DATABASE [MTS_Master] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [MTS_Master] SET ANSI_WARNINGS ON 
GO
ALTER DATABASE [MTS_Master] SET ARITHABORT OFF 
GO
ALTER DATABASE [MTS_Master] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [MTS_Master] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [MTS_Master] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [MTS_Master] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [MTS_Master] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [MTS_Master] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [MTS_Master] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [MTS_Master] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [MTS_Master] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [MTS_Master] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [MTS_Master] SET  DISABLE_BROKER 
GO
ALTER DATABASE [MTS_Master] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [MTS_Master] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [MTS_Master] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [MTS_Master] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [MTS_Master] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [MTS_Master] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [MTS_Master] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [MTS_Master] SET  READ_WRITE 
GO
ALTER DATABASE [MTS_Master] SET RECOVERY FULL 
GO
ALTER DATABASE [MTS_Master] SET  MULTI_USER 
GO
ALTER DATABASE [MTS_Master] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [MTS_Master] SET DB_CHAINING OFF 
GO
GRANT CONNECT TO [d3j409] AS [dbo]
GO
GRANT CONNECT TO [D3J410] AS [dbo]
GO
GRANT CONNECT TO [msdadmin] AS [dbo]
GO
GRANT CONNECT TO [MTAdmin] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Dev] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Dev] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Lite] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Lite] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Reader] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Reader] AS [dbo]
GO
GRANT CONNECT TO [MTUser] AS [dbo]
GO
GRANT SHOWPLAN TO [MTUser] AS [dbo]
GO
GRANT CONNECT TO [pogo\MTS_DB_Dev] AS [dbo]
GO
