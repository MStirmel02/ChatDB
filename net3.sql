IF EXISTS(SELECT 1 FROM master.dbo.sysdatabases
			WHERE name = 'ChatDB')
BEGIN
	DROP DATABASE ChatDB
	print '' print '*** dropping database ChatDB ***'
END
GO

print '' print '*** creating database ChatDB ***'
GO
CREATE DATABASE [ChatDB]
GO
GO
USE [ChatDB]
GO

GO
print '' print '*** TABLES ***'
GO

GO
PRINT '' PRINT '***ROLES***'
GO
CREATE TABLE [dbo].[Roles](			
	[RoleID]			[NVARCHAR](50) 				NOT NULL
,	[Description]		[NVARCHAR](255)				NOT NULL
, 	CONSTRAINT 			[pk_roleid]		
	PRIMARY KEY			([RoleID])
)
GO

GO
PRINT '' PRINT '***USERS***'
GO
CREATE TABLE [dbo].[Users](
	[UserID]			[NVARCHAR](50)				NOT NULL
,	[PasswordHash]		[NVARCHAR](255)				NOT NULL
,	[Email]				[NVARCHAR](255)					NULL
,	[DateCreated]		[DATETIME]					NOT NULL	DEFAULT	 GETDATE()
,	[LastLoggedIn]		[DATETIME]					NOT NULL	DEFAULT  GETDATE()
,	CONSTRAINT [pk_userid]
	PRIMARY KEY([UserID])
)
GO


PRINT '' PRINT '***CHANNELS***'
GO
CREATE TABLE [dbo].[Channels](
	[ChannelID]			[NVARCHAR](255)				NOT NULL
,	[UsersInChannel]	[INT]						NOT NULL 	DEFAULT 0
,	[ChannelHash]		[NVARCHAR](255)				NOT NULL
, 	[Deleted]			[BIT]						NOT NULL 	DEFAULT 0
,	CONSTRAINT [pk_channelid]				
	PRIMARY KEY([ChannelID])
)

PRINT '' PRINT '***USERCHANNELS***'
GO
CREATE TABLE [dbo].[UserChannels](
	[ChannelID] 		[NVARCHAR](255) 			NOT NULL
,	[UserID]			[NVARCHAR](50)				NOT NULL
, 	[RoleID]			[NVARCHAR](50)				NOT NULL
, 	CONSTRAINT [pk_userchannels]
	PRIMARY KEY([ChannelID], [UserID])
, 	CONSTRAINT [fk_userchannels_channels]	
	FOREIGN KEY([ChannelID])
	REFERENCES [Channels]([ChannelID])
,	CONSTRAINT [fk_userchannels_users]	
	FOREIGN KEY([UserID])
	REFERENCES [Users]([UserID])
,	CONSTRAINT [fk_userchannels_roleid] 	
	FOREIGN KEY([RoleID])
	REFERENCES [Roles]([RoleID])
)
GO


PRINT '' PRINT '***MESSAGES***'
GO
CREATE TABLE [dbo].[Messages](
	[MessageID]		[INT]			IDENTITY(1,1)   NOT NULL	
,	[ChannelID]		[NVARCHAR](255)					NOT NULL	
,	[UserID]		[NVARCHAR](50)					NOT NULL
,	[Content] 		[TEXT]							NOT NULL
,	[TimeSent]		[DATETIME]						NOT NULL	DEFAULT	GETDATE()
,	CONSTRAINT [pk_messageid]			
	PRIMARY KEY([MessageID])
,	CONSTRAINT [fk_messages_channelID] 
	FOREIGN KEY([ChannelID]) 
	REFERENCES [Channels]([ChannelID]) ON UPDATE CASCADE
,	CONSTRAINT [fk_messages_userID]	
	FOREIGN KEY([UserID])  
	REFERENCES [Users]([UserID]) ON UPDATE CASCADE
)
GO

GO
-- Only two roles we need.
INSERT INTO roles
VALUES ('User','This is a normal channel user, they can chat, and thats about it.'), ('Creator','This user created the channel. They can delete the channel at any time.')
GO


GO
print '' print '*** STORED PROCEDURES ***'
GO

GO
print '' print '*** sp_create_user ***'
GO
CREATE PROC sp_create_user(
	@UserID				[NVARCHAR](50)
,	@PasswordHash		[NVARCHAR](255)
)
AS BEGIN

	INSERT INTO [Users] (
		[UserID]
	,	[PasswordHash]
	,	[DateCreated]
	,	[LastLoggedIn]
	) VALUES (
		@UserID
	,	@PasswordHash
	,	GETDATE()
	,	GETDATE()
	)

END
GO


GO
print '' print '*** sp_create_channel ***'
GO
CREATE PROC sp_create_channel(
	@UserID				[NVARCHAR](50)
,	@ChannelHash		[NVARCHAR](255)
,	@ChannelID			[NVARCHAR](255)
) 
AS BEGIN

	INSERT INTO [Channels] (
		[ChannelID]
	,	[UsersInChannel]
	,	[ChannelHash]
	) VALUES (
		@ChannelID
	,	1
	,	@ChannelHash
	)

	INSERT INTO [UserChannels] (
		[ChannelID]
	,	[UserID]
	,	[RoleID]
	) VALUES (
		@ChannelID
	,	@UserID
	,	'Creator'
	)

END
GO

GO
print '' print '*** sp_create_message ***'
GO
CREATE PROC sp_create_message(
	@UserID				[NVARCHAR](50)
,	@Content			[TEXT]
,	@ChannelID			[NVARCHAR](255)
)
AS BEGIN
	INSERT INTO [Messages] (
		[ChannelID]
	,	[UserID]
	,	[Content]
	) VALUES ( 
		@ChannelID
	,	@UserID
	,	@Content
	)
END
GO

GO
print '' print '*** sp_view_channel_messages ***'
GO
CREATE PROC sp_view_channel_messages(
	@ChannelID			[NVARCHAR](255)
)
AS BEGIN 
	SELECT [UserID], [Content], [TimeSent]
	FROM [Messages]
	WHERE [ChannelID] = @ChannelID
	ORDER BY [TimeSent] ASC
END
GO

GO
print '' print '*** sp_user_sign_in ***'
GO
CREATE PROC sp_user_sign_in(
	@UserID				[NVARCHAR](50)
,	@PasswordHash		[NVARCHAR](255)
)
AS BEGIN
	DECLARE @count INT;

	SELECT @count = COUNT([UserID])
	FROM [Users]
	WHERE [UserID] = @UserID AND [PasswordHash] = @PasswordHash

	IF @count = 1
	BEGIN
		BEGIN TRY 
			BEGIN TRANSACTION
				UPDATE [Users]
				SET [LastLoggedIn] = GETDATE()
				WHERE [UserID] = @UserID
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
		END CATCH
	END
		
END
GO

GO
print '' print '*** sp_user_view_channels ***'
GO
CREATE PROC sp_user_view_channels(
	@UserID				[NVARCHAR](50)
)
AS BEGIN
	SELECT [UserChannels].[ChannelID], [UserChannels].[RoleID],
	[Channels].[UsersInChannel]
	FROM [UserChannels]
	INNER JOIN [Channels]
	ON [Channels].[ChannelID] = [UserChannels].[ChannelID]
	WHERE [UserID] = @UserID
END
GO

GO
print '' print '*** sp_user_channel_sign_in ***'
GO
CREATE PROC sp_user_channel_sign_in(
	@UserID				[NVARCHAR](50)
,	@ChannelID			[NVARCHAR](255)
,	@ChannelHash		[NVARCHAR](255)
)
AS BEGIN
	DECLARE @ChannelCount [INT]

	SELECT @ChannelCount = COUNT([ChannelID])
	FROM [Channels]
	WHERE [ChannelID] = @ChannelID AND [ChannelHash] = @ChannelHash AND [Deleted] = 0

	IF @ChannelCount = 1 
	BEGIN
		BEGIN TRY 
			BEGIN TRANSACTION
				INSERT INTO [UserChannels] (
					ChannelID
				,	UserID
				,	RoleID
				) VALUES (
					@ChannelID
				,	@UserID
				,	'User'
				)
				UPDATE [Channels]
				SET [UsersInChannel] = [UsersInChannel] + 1
				WHERE [ChannelID] = @ChannelID
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
		END CATCH
	END

END
GO

GO
print '' print '*** sp_user_channel_sign_out ***'
GO
CREATE PROC sp_user_channel_sign_out(
	@UserID				[NVARCHAR](50)
,	@ChannelID			[NVARCHAR](255)
)
AS BEGIN

	DECLARE @ChannelCount [INT]

	SELECT @ChannelCount = COUNT([ChannelID])
	FROM [UserChannels]
	WHERE [ChannelID] = @ChannelID AND [UserID] = @UserID
	
	IF @ChannelCount = 1
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION
				DELETE FROM [UserChannels]
				WHERE [ChannelID] = @ChannelID AND [UserID] = @UserID
				UPDATE [Channels]
				SET [UsersInChannel] = [UsersInChannel] - 1
				WHERE [ChannelID] = @ChannelID
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
		END CATCH
	END
END
GO
		
		

GO
print '' print '*** sp_delete_channel ***'
GO
CREATE PROC sp_delete_channel(
	@ChannelID			[NVARCHAR](255)
)
AS BEGIN
		BEGIN TRY
			BEGIN TRANSACTION
				DELETE FROM [UserChannels]
				WHERE [ChannelID] = @ChannelID
				UPDATE [Channels]
				SET [Deleted] = 1
				, [ChannelID] = NEWID()
				WHERE [ChannelID] = @ChannelID
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
		END CATCH
END
GO
