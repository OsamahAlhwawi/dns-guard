import { z } from "zod";

export const usernameSchema = z
  .string()
  .regex(/^[a-zA-Z0-9]+$/, "username must be alphanumeric")
  .min(3)
  .max(20);

export const passwordSchema = z
  .string()
  .min(8)
  .refine((p) => /[A-Za-z]/.test(p), "password must contain a letter")
  .refine((p) => /\d/.test(p), "password must contain a number")
  .refine((p) => /[^A-Za-z0-9]/.test(p), "password must contain a symbol");

export const registerSchema = z.object({
  username: usernameSchema,
  password: passwordSchema,
  full_name: z.string().min(1).max(100).optional(),
  email: z.string().email().optional(),
});

export const loginSchema = z.object({
  username: usernameSchema,
  password: z.string().min(1),
});

export const updateUserSchema = z.object({
  is_active: z.boolean().optional(),
  is_suspended: z.boolean().optional(),
  role: z.enum(["user", "admin"]).optional(),
  daily_limit: z.number().int().nonnegative().optional(),
  expires_at: z.string().datetime().nullable().optional(),
  full_name: z.string().min(1).max(100).optional(),
  email: z.string().email().nullable().optional(),
});

export const adminCreateUserSchema = registerSchema.extend({
  role: z.enum(["user", "admin"]).default("user"),
  is_active: z.boolean().default(true),
  daily_limit: z.number().int().nonnegative().optional(),
});

export const profileUpdateSchema = z.object({
  full_name: z.string().min(1).max(100).optional(),
  email: z.string().email().nullable().optional(),
});

export const changePasswordSchema = z.object({
  current_password: z.string().min(1),
  new_password: passwordSchema,
});

export const refreshSchema = z.object({
  refresh_token: z.string().min(1),
});
