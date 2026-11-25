import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

export interface AuthPayload {
  sub: string;
  email: string;
}

interface AuthedRequest {
  headers: Record<string, string | string[] | undefined>;
  user?: AuthPayload;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const header = req.headers['authorization'];
    const value = Array.isArray(header) ? header[0] : header;
    const [scheme, token] = (value ?? '').split(' ');

    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Missing bearer token');
    }

    try {
      // Access token được ký bằng secret mặc định của JwtModule;
      // refresh token dùng secret khác nên sẽ bị từ chối ở đây.
      req.user = await this.jwtService.verifyAsync<AuthPayload>(token);
      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
